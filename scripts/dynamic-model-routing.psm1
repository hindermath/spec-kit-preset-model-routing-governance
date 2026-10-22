#Requires -Version 7.0
<#
.SYNOPSIS
    Deterministische Phasenauswahl / Deterministic phase selection.
.DESCRIPTION
    DE: Reiner Auswahlkern. Liest Evidence und Konfigurations-Hashes, startet
    keine Modelle und schreibt keine Profile. Kandidaten sind lokal genehmigt.
    EN: Pure selection core. Reads evidence/configuration hashes, never invokes
    models or writes profiles. Candidate suitability requires local approval.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:MRRanks = @{ 'script-only'=0; 'fast-mechanical'=10; 'long-running-implementation'=20; 'coding-review'=30; 'frontier-reasoning'=40 }
$script:MREfforts = @{ none=0; minimal=1; low=2; medium=3; high=4; xhigh=5; max=6; ultra=7 }
$script:MRExecutables = @{ Codex='codex'; Claude='claude'; Copilot='copilot'; Antigravity='agy'; OpenCode='opencode' }

function Get-MRSha256 {
    param([Parameter(Mandatory)][string] $Text)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()
}

function Assert-MRValue {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

function Get-MRUtcTime {
    param([Parameter(Mandatory)] $Value)
    if ($Value -is [DateTimeOffset]) { return $Value }
    if ($Value -is [DateTime]) { return [DateTimeOffset]::new($Value.ToUniversalTime()) }
    Assert-MRValue ([string]$Value -match '^\d{4}-\d{2}-\d{2}T.*(Z|\+00:00)$') 'Explicit UTC timestamp required.'
    return [DateTimeOffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)
}

function Read-MRDocument {
    param([Parameter(Mandatory)][string] $Path)
    $options = @{AsHashtable=$true}
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $options.DateKind='String' }
    return Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json @options
}

function Get-MRCatalog {
    param([Parameter(Mandatory)][string] $Root)
    $rootPath = [IO.Path]::GetFullPath($Root)
    $registryPath=Join-Path $rootPath '.registry'
    $registryText=''
    if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
        $registry=Read-MRDocument $registryPath
        $paths=[Collections.Generic.List[object]]::new()
        foreach ($entry in @($registry.presets.GetEnumerator() | Sort-Object Key)) {
            Assert-MRValue ([string]$entry.Key -match '^[a-z0-9][a-z0-9-]*$' -and $entry.Value.enabled -is [bool]) 'Invalid installed preset registry.'
            $registryText+="$($entry.Key):$($entry.Value.enabled):$($entry.Value.version)`n"
            if ($entry.Value.enabled) {
                $path=Join-Path (Join-Path $rootPath $entry.Key) 'model-routing.json'
                Assert-MRValue (Test-Path -LiteralPath $path -PathType Leaf) 'Enabled preset has no routing catalog.'
                $paths.Add((Get-Item -LiteralPath $path))
            }
        }
        $files=@($paths.ToArray() | Sort-Object FullName)
    } elseif (Test-Path -LiteralPath (Join-Path $rootPath 'model-routing.json') -PathType Leaf) {
        $files=@(Get-Item -LiteralPath (Join-Path $rootPath 'model-routing.json'))
    } else {
        # Explicit source/fixture roots only: never scan caches or nested repos.
        $files=@(Get-ChildItem -LiteralPath $rootPath -Directory | Where-Object { -not $_.Name.StartsWith('.') } | ForEach-Object {
            $path=Join-Path $_.FullName 'model-routing.json'
            if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Item -LiteralPath $path }
        } | Sort-Object FullName)
    }
    Assert-MRValue ($files.Count -gt 0) 'Routing catalog missing.'
    $commands = @{}
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $payload = [Text.StringBuilder]::new()
    [void]$payload.Append($registryText)
    foreach ($file in $files) {
        $data = Read-MRDocument $file.FullName
        Assert-MRValue ([string]$data.schemaVersion -eq '1.0' -and [string]$data.fallbackPolicy -eq 'fail-closed') 'Unsupported routing catalog.'
        Assert-MRValue ($script:MRRanks.ContainsKey([string]$data.defaultRole)) 'Unknown default role.'
        Assert-MRValue ($ids.Add([string]$data.presetId)) 'Duplicate preset routing catalog.'
        Assert-MRValue ($data.commands -is [hashtable]) 'commands must be an object.'
        $relative = [IO.Path]::GetRelativePath($rootPath, $file.FullName).Replace('\','/')
        $normalized = (Get-Content -LiteralPath $file.FullName -Raw).Replace("`r`n","`n").Replace("`r","`n")
        [void]$payload.Append($relative).Append("`n").Append($normalized).Append("`n")
        foreach ($entry in $data.commands.GetEnumerator()) {
            $role = [string]$entry.Value
            Assert-MRValue ($script:MRRanks.ContainsKey($role)) 'Unknown command role.'
            if (-not $commands.ContainsKey($entry.Key) -or $script:MRRanks[$role] -gt $script:MRRanks[$commands[$entry.Key]]) {
                $commands[$entry.Key] = $role
            }
        }
    }
    return @{ commands=$commands; sha256=(Get-MRSha256 $payload.ToString()); presetIds=@($ids | Sort-Object) }
}

function Get-MRContextHash {
    param([Parameter(Mandatory)][hashtable] $Context, [Parameter(Mandatory)][string] $ProjectRoot, [string] $ExecutionRoot='')
    Assert-MRValue ([IO.Path]::GetFullPath([string]$Context.projectRoot) -ceq [IO.Path]::GetFullPath($ProjectRoot)) 'Project scope changed.'
    Assert-MRValue (-not [string]::IsNullOrWhiteSpace([string]$Context.providerContextId)) 'Provider/account context missing.'
    Assert-MRValue ($Context.bindings -is [array] -and $Context.bindings.Count -gt 0) 'Explicit account/provider/configuration bindings required.'
    foreach ($kind in @('account','provider','project')) {
        Assert-MRValue (@($Context.bindings | Where-Object { $_.kind -ceq $kind }).Count -gt 0) "Context binding coverage missing: $kind"
    }
    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append([IO.Path]::GetFullPath($ProjectRoot)).Append("`n").Append([string]$Context.providerContextId).Append("`n")
    foreach ($binding in @($Context.bindings | Sort-Object path)) {
        $path = [IO.Path]::GetFullPath([string]$binding.path)
        Assert-MRValue (Test-Path -LiteralPath $path -PathType Leaf) 'Context binding unavailable.'
        # Only hashes leave this function: never serialize account/config bytes.
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-MRValue ($actual -ceq [string]$binding.sha256) 'Account/provider/configuration drift.'
        if ($binding.kind -eq 'project' -and -not [string]::IsNullOrWhiteSpace($ExecutionRoot)) {
            $relative=[IO.Path]::GetRelativePath([IO.Path]::GetFullPath($ProjectRoot), $path)
            Assert-MRValue (-not $relative.StartsWith('..') -and -not [IO.Path]::IsPathRooted($relative)) 'Project binding must belong to the bound repository.'
            $copy=Join-Path ([IO.Path]::GetFullPath($ExecutionRoot)) $relative
            Assert-MRValue ((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $actual) 'Execution worktree configuration drift.'
        }
        [void]$builder.Append([string]$binding.kind).Append("`n").Append($path).Append("`n").Append($actual).Append("`n")
    }
    return Get-MRSha256 $builder.ToString()
}

function Test-MREvidence {
    param([Parameter(Mandatory)][hashtable] $Evidence, [Parameter(Mandatory)][DateTimeOffset] $Now)
    foreach ($key in @('path','sha256','reviewer','reviewedAt','expiresAt')) {
        Assert-MRValue ($Evidence.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace([string]$Evidence[$key])) "Evidence $key missing."
    }
    Assert-MRValue ((Get-MRUtcTime $Evidence.reviewedAt) -le $Now -and (Get-MRUtcTime $Evidence.expiresAt) -gt $Now) 'Suitability evidence expired/future-dated.'
    Assert-MRValue ((Get-FileHash -LiteralPath $Evidence.path -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$Evidence.sha256) 'Suitability evidence hash changed.'
}

function Get-MRAdapterProfile {
    param([Parameter(Mandatory)][string] $Harness, [Parameter(Mandatory)][hashtable] $Candidate, [Parameter(Mandatory)][string] $Role)
    Assert-MRValue ($script:MRExecutables.ContainsKey($Harness)) 'Unknown harness.'
    $model = [string]$Candidate.model
    $effort = [string]$Candidate.effort
    Assert-MRValue ($model -match '^[A-Za-z0-9][A-Za-z0-9._:/-]*$') 'Invalid concrete model ID.'
    Assert-MRValue ($script:MREfforts.ContainsKey($effort)) 'Unknown reasoning effort.'
    $probe = 'Reply exactly MODEL_READY without using tools.'
    # No auto approval, provider switching, model aliases, fallback chains or
    # shell evaluation. Execution access remains the outer runner's authority.
    switch ($Harness) {
        Codex {
            $base = @('exec','--ephemeral','--json','--model',$model,'--config',"model_reasoning_effort=`"$effort`"",'--cd','{worktree}')
            $preflight = $base + @('--sandbox','read-only',$probe)
            $permission = if ($Role -eq 'fast-mechanical') { 'read-only' } else { 'workspace-write' }
            $arguments = $base + @('--sandbox',$permission,'--output-last-message','{outputFile}','{prompt}')
        }
        Claude {
            $settings=@{availableModels=@($model);fallbackModel=@();switchModelsOnFlag=$false} | ConvertTo-Json -Compress
            $base = @('--print','--no-session-persistence','--model',$model,'--effort',$effort,'--output-format','stream-json','--verbose','--settings',$settings)
            $preflight = $base + @('--tools','','--permission-mode','plan',$probe)
            # Claude Code 2.1.304 documents manual, not default. Requests
            # requiring approval stay denied in unattended execution.
            $arguments = $base + @('--permission-mode','manual','--permission-prompts','none','{prompt}')
        }
        Copilot {
            $base = @('--model',$model,'--reasoning-effort',$effort,'--output-format','json')
            $preflight = $base + @('--available-tools','','-p',$probe)
            $arguments = $base + @('-p','{prompt}')
        }
        Antigravity {
            $base = @('--model',$model,'--effort',$effort,'--output-format','json','--print-timeout','120')
            $preflight = $base + @('--mode','plan','--print',$probe)
            $arguments = $base + @('--mode','accept-edits','--print','{prompt}')
        }
        OpenCode {
            Assert-MRValue ($model.Contains('/') -and $Candidate.ContainsKey('variant') -and [string]$Candidate.variant -match '^[A-Za-z0-9._-]+$') 'OpenCode requires provider/model and a verified variant.'
            $base = @('run','--standalone','--model',"$model#$($Candidate.variant)",'--format','json')
            $preflight = $base + @('--agent','plan',$probe)
            $agent = if ($Role -eq 'fast-mechanical') { 'plan' } else { 'build' }
            $arguments = $base + @('--agent',$agent,'{prompt}')
        }
    }
    return @{ routingRole=$Role; agentFamily=$Harness; model=$model; reasoningEffort=$effort; executable=$script:MRExecutables[$Harness];
        preflight=@{executable=$script:MRExecutables[$Harness];arguments=$preflight}; arguments=$arguments;
        executionIdentityRequired=$true; nativeConformanceVerified=(@($Candidate.capabilities) -ccontains 'native-model-effort-acknowledgement'); outputContract='native-json-plus-existing-phase-result'; timeoutSeconds=3600 }
}

function Resolve-MRSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $Config,
        [Parameter(Mandatory)][hashtable] $Requirements,
        [Parameter(Mandatory)][hashtable] $Catalog,
        [Parameter(Mandatory)][string] $Harness,
        [Parameter(Mandatory)][string] $HarnessVersion,
        [Parameter(Mandatory)][string] $ProjectRoot,
        [DateTimeOffset] $Now = [DateTimeOffset]::UtcNow
    )
    $result = @{ schemaVersion='1.0'; status='Blocked'; exitCode=3; reason=''; nextAction='Correct the local routing input and repeat Preview.' }
    try {
        Assert-MRValue ($script:MRExecutables.ContainsKey($Harness)) 'Unknown harness.'
        if ($Config.Count -eq 0) {
            $result.status = if ($Harness -eq 'OpenCode') { 'NotConfigured' } else { 'NeedsClarification' }
            $result.exitCode = if ($Harness -eq 'OpenCode') { 5 } else { 4 }
            $result.reason = 'No explicitly approved local configuration.'
            return $result
        }
        if ([string]$Config.schemaVersion -ne '3.0') {
            $result.status='RefreshRequired'; $result.exitCode=2; $result.reason='Legacy profile remains readable; explicit migration to schema 3.0 required.'
            return $result
        }
        Assert-MRValue ($Config.harness.family -ceq $Harness) 'Harness change requires explicit authority.'
        Assert-MRValue ($Config.harness.version -ceq $HarnessVersion) 'Harness version drift.'
        $contextHash = Get-MRContextHash $Config.context $ProjectRoot
        $policy = $Config.policy
        Assert-MRValue ([string]$policy.selectionMode -eq 'quality-with-efficiency' -and [string]$policy.fallbackPolicy -eq 'fail-closed') 'Unsupported selection/fallback policy.'
        Assert-MRValue (-not [string]::IsNullOrWhiteSpace([string]$policy.approvedBy) -and (Get-MRUtcTime $policy.approvedAt) -le $Now) 'Local policy approval required.'
        Assert-MRValue ($policy.catalogSha256 -ceq $Catalog.sha256 -and $policy.contextSha256 -ceq $contextHash) 'Policy/catalog/context binding changed.'
        Assert-MRValue ($Config.candidates -is [array]) 'Explicit candidate array required.'
        Assert-MRValue ($policy.candidatesSha256 -ceq (Get-MRSha256 ($Config.candidates | ConvertTo-Json -Depth 40 -Compress))) 'Approved candidate pool changed.'
        Assert-MRValue (@($Config.candidates | ForEach-Object {$_.id} | Sort-Object -Unique).Count -eq $Config.candidates.Count) 'Duplicate candidate IDs.'
        Assert-MRValue ($Config.inventory.models -is [array]) 'Model inventory must be an array.'
        Test-MREvidence $Config.inventory.source $Now
        $age = ($Now - (Get-MRUtcTime $Config.inventory.collectedAt)).TotalHours
        $maxAge = if ($policy.ContainsKey('maximumInventoryAgeHours')) { [double]$policy.maximumInventoryAgeHours } else { 24 }
        Assert-MRValue ($maxAge -gt 0 -and $maxAge -le 24) 'Inventory TTL must be at most 24 hours.'
        if ($age -lt 0 -or $age -gt $maxAge) {
            $result.status='RefreshRequired'; $result.exitCode=2; $result.reason='Inventory expired or future-dated.'; return $result
        }
        foreach ($field in @('command','role','complexity','risk','contextTokens','capabilities')) {
            Assert-MRValue ($Requirements.ContainsKey($field)) "Phase requirement $field missing."
        }
        Assert-MRValue ($Requirements.ContainsKey('schemaVersion') -and [string]$Requirements.schemaVersion -ceq '1.0') 'Explicit phase requirements schema 1.0 required.'
        $command = [string]$Requirements.command
        Assert-MRValue ($Catalog.commands.ContainsKey($command)) 'No command routing contract.'
        $role = [string]$Catalog.commands[$command]
        Assert-MRValue ($Requirements.role -ceq $role) 'Declared role does not match strongest command role.'
        Assert-MRValue (@('simple','normal','challenging') -contains [string]$Requirements.complexity) 'Unknown complexity.'
        Assert-MRValue (@('low','normal','high') -contains [string]$Requirements.risk) 'Unknown risk.'
        Assert-MRValue ($Requirements.capabilities -is [array] -and $Requirements.contextTokens -is [ValueType] -and $Requirements.contextTokens -isnot [bool] -and [double]$Requirements.contextTokens -ge 0 -and [double]$Requirements.contextTokens -eq [long]$Requirements.contextTokens) 'Explicit nonnegative integer context and capability array required.'
        if ($role -eq 'script-only') {
            $result.status='Aligned'; $result.exitCode=0; $result.reason='Deterministic command: no model process.'; $result.scriptOnly=$true; return $result
        }
        $complexity = [string]$Requirements.complexity
        if ($role -in @('frontier-reasoning','coding-review') -and $complexity -eq 'simple') { $complexity='normal' }
        if ($Requirements.risk -eq 'high' -or @($Requirements.capabilities | Where-Object { $_ -in @('security','architecture') }).Count -gt 0) { $complexity='challenging' }
        $minimumEffort = if ($complexity -eq 'challenging' -or $role -eq 'frontier-reasoning') { 4 } elseif ($complexity -eq 'normal') { 3 } else { 2 }
        $eligible = [Collections.Generic.List[hashtable]]::new()
        $rejected = [Collections.Generic.List[object]]::new()
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($candidate in @($Config.candidates)) {
            try {
                foreach ($field in @('id','model','effort','providerContextId','roles','complexities','risks','capabilities','contextTokens','preferenceRank','evidence')) {
                    Assert-MRValue ($candidate.ContainsKey($field)) "Candidate $field missing."
                }
                Assert-MRValue ($seen.Add([string]$candidate.id)) 'Duplicate candidate ID.'
                $models = @($Config.inventory.models | Where-Object { [string]$_.id -ceq [string]$candidate.model })
                Assert-MRValue ($models.Count -eq 1) 'Model absent or ambiguous in inventory.'
                Assert-MRValue ($models[0].efforts -is [array] -and @($models[0].efforts) -ccontains [string]$candidate.effort) 'Reasoning effort unverified.'
                Assert-MRValue ($script:MREfforts.ContainsKey([string]$candidate.effort) -and $script:MREfforts[[string]$candidate.effort] -ge $minimumEffort) 'Reasoning below phase floor.'
                if ($Harness -eq 'OpenCode') {
                    $variants = @($models[0].variants | Where-Object { $_.id -ceq $candidate.variant -and $_.effort -ceq $candidate.effort })
                    Assert-MRValue ($variants.Count -eq 1) 'OpenCode variant/effort unverified.'
                }
                Assert-MRValue ($candidate.providerContextId -ceq $Config.context.providerContextId) 'Provider/account mismatch.'
                foreach ($field in @('roles','complexities','risks','capabilities')) { Assert-MRValue ($candidate[$field] -is [array]) "Candidate $field must be an array." }
                Assert-MRValue (@($candidate.roles) -ccontains $role) 'Role suitability unverified.'
                Assert-MRValue (@($candidate.complexities) -ccontains $complexity) 'Complexity suitability unverified.'
                Assert-MRValue (@($candidate.risks) -ccontains [string]$Requirements.risk) 'Risk suitability unverified.'
                Assert-MRValue (@($Requirements.capabilities | Where-Object { @($candidate.capabilities) -cnotcontains [string]$_ }).Count -eq 0) 'Required capability missing.'
                Assert-MRValue ($candidate.contextTokens -is [ValueType] -and $candidate.contextTokens -isnot [bool] -and [double]$candidate.contextTokens -eq [long]$candidate.contextTokens -and [double]$candidate.contextTokens -ge [double]$Requirements.contextTokens) 'Insufficient verified integer context.'
                Assert-MRValue ($candidate.preferenceRank -is [ValueType] -and $candidate.preferenceRank -isnot [bool] -and [double]$candidate.preferenceRank -ge 0 -and [double]$candidate.preferenceRank -eq [int]$candidate.preferenceRank) 'Explicit approved resource/preference rank required.'
                Test-MREvidence $candidate.evidence $Now
                [void](Get-MRAdapterProfile $Harness $candidate $role)
                $eligible.Add($candidate)
            } catch {
                $rejected.Add(@{id=if ($candidate.ContainsKey('id')) {$candidate.id} else {'unknown'};reason=$_.Exception.Message})
            }
        }
        $result.rejected=@($rejected.ToArray())
        if ($eligible.Count -eq 0) {
            $result.status='NeedsClarification'; $result.exitCode=4; $result.reason='No candidate has complete suitability evidence.'; return $result
        }
        $ordered = @($eligible.ToArray() | Sort-Object preferenceRank)
        if (@($ordered | Where-Object { $_.preferenceRank -eq $ordered[0].preferenceRank }).Count -ne 1) {
            $result.status='NeedsClarification'; $result.exitCode=4; $result.reason='Approved candidate preference is ambiguous.'; return $result
        }
        $selected = $ordered[0]
        $result.status='Aligned'; $result.exitCode=0; $result.reason='Smallest approved preference rank among fully suitable candidates; access not yet proved.'
        $result.scriptOnly=$false
        $result.selection=@{candidateId=$selected.id;harness=$Harness;harnessVersion=$HarnessVersion;model=$selected.model;effort=$selected.effort;effectiveComplexity=$complexity;requirements=$Requirements;
            catalogSha256=$Catalog.sha256;contextSha256=$contextHash;inventorySha256=(Get-MRSha256 ($Config.inventory | ConvertTo-Json -Depth 40 -Compress));
            policySha256=(Get-MRSha256 ($policy | ConvertTo-Json -Depth 40 -Compress));evidenceSha256=$selected.evidence.sha256;selectedAt=$Now.ToString('o');access='NotProbed'}
        $result.profile=Get-MRAdapterProfile $Harness $selected $role
        $result.nextAction='Execution requires separate authority and exactly one bounded preflight; never retry/fallback silently.'
        return $result
    } catch {
        $result.reason=$_.Exception.Message
        return $result
    }
}

function Test-MRExecutionIdentity {
    param([Parameter(Mandatory)][hashtable] $Receipt, [Parameter(Mandatory)][hashtable] $Selection)
    # A zero exit code or a model's self-description is not provider evidence.
    foreach ($field in @('harness','model','effort','contextSha256','policySha256','inventorySha256')) {
        Assert-MRValue ($Receipt.ContainsKey($field) -and [string]$Receipt[$field] -ceq [string]$Selection[$field]) "Execution identity mismatch: $field"
    }
    Assert-MRValue ($Receipt.source -eq 'harness-metadata' -and $Receipt.fallbackOccurred -is [bool] -and -not $Receipt.fallbackOccurred) 'Verified native metadata without fallback required.'
}

function Get-MRNativeReceipt {
    param([Parameter(Mandatory)][string[]] $Output, [Parameter(Mandatory)][hashtable] $Selection)
    $identities=[Collections.Generic.List[object]]::new()
    $noFallbackEvidence=$false
    foreach ($line in $Output) {
        try { $nativeEvent=$line | ConvertFrom-Json -AsHashtable -ErrorAction Stop } catch { continue }
        if ($nativeEvent -isnot [hashtable] -or -not $nativeEvent.ContainsKey('type')) { continue }
        # Read only native control-plane fields, never assistant text/content,
        # a prompt-generated file, or a model's claim about its own identity.
        $native=$null
        switch ([string]$Selection.harness) {
            Codex { if ($nativeEvent.type -eq 'thread.started' -and $nativeEvent.ContainsKey('model') -and $nativeEvent.ContainsKey('reasoning_effort')) { $native=@{model=$nativeEvent.model;effort=$nativeEvent.reasoning_effort} } }
            Claude { if ($nativeEvent.type -eq 'system' -and $nativeEvent.subtype -eq 'init' -and $nativeEvent.ContainsKey('model') -and $nativeEvent.ContainsKey('effort')) { $native=@{model=$nativeEvent.model;effort=$nativeEvent.effort} } }
            Copilot { if ($nativeEvent.type -eq 'session.start' -and $nativeEvent.ContainsKey('data') -and $nativeEvent.data.ContainsKey('selectedModel') -and $nativeEvent.data.ContainsKey('reasoningEffort')) { $native=@{model=$nativeEvent.data.selectedModel;effort=$nativeEvent.data.reasoningEffort} } }
            Antigravity { if ($nativeEvent.type -eq 'system' -and $nativeEvent.ContainsKey('model') -and $nativeEvent.ContainsKey('effort')) { $native=@{model=$nativeEvent.model;effort=$nativeEvent.effort} } }
            OpenCode { if ($nativeEvent.type -eq 'session.created' -and $nativeEvent.ContainsKey('model') -and $nativeEvent.ContainsKey('effort')) { $native=@{model=$nativeEvent.model;effort=$nativeEvent.effort} } }
        }
        if ($null -ne $native) {
            Assert-MRValue ([string]$native.model -ceq [string]$Selection.model -and [string]$native.effort -ceq [string]$Selection.effort) 'Native metadata reports a different model or effort.'
            Assert-MRValue ($nativeEvent.ContainsKey('fallbackOccurred') -and $nativeEvent.fallbackOccurred -is [bool] -and -not $nativeEvent.fallbackOccurred) 'Native no-fallback acknowledgement unavailable or fallback occurred.'
            $noFallbackEvidence=$true
            $identities.Add($native)
        }
    }
    Assert-MRValue ($identities.Count -gt 0) 'Native model/effort acknowledgement unavailable: block rather than infer identity from exit code or requested arguments.'
    Assert-MRValue $noFallbackEvidence 'Native no-fallback evidence missing.'
    $receipt=@{source='harness-metadata';fallbackOccurred=$false}
    foreach ($field in @('harness','model','effort','contextSha256','policySha256','inventorySha256')) { $receipt[$field]=$Selection[$field] }
    return $receipt
}

function Invoke-MRBoundedProcess {
    param([Parameter(Mandatory)][hashtable] $Runner, [Parameter(Mandatory)][hashtable] $Values, [Parameter(Mandatory)][string] $WorkingDirectory, [ValidateRange(1,86400)][int] $TimeoutSeconds=120)
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=(Get-Process -Id $PID).Path; $info.WorkingDirectory=[IO.Path]::GetFullPath($WorkingDirectory)
    $info.UseShellExecute=$false; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $resolved=[Collections.Generic.List[string]]::new()
    foreach ($argument in @($Runner.arguments)) {
        $value=[string]$argument
        foreach ($item in $Values.GetEnumerator()) { $value=$value.Replace("{$($item.Key)}",[string]$item.Value) }
        $resolved.Add($value)
    }
    $payload=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @($resolved.ToArray()) -Compress)))
    foreach ($argument in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $PSScriptRoot 'invoke-model-routing-process.ps1'),'-Executable',[string]$Runner.executable,'-ArgumentsBase64',$payload)) { $info.ArgumentList.Add($argument) }
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$info; $started=$false
    try {
        $started=$process.Start(); Assert-MRValue $started 'Process could not start.'
        $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds*1000)) {
            $process.Kill($true); [void]$process.WaitForExit(2000)
            return @{exitCode=124;output=@();reason='Bounded process timed out; no retry.'}
        }
        # Native Windows stdout uses CRLF. Remove only the line delimiter,
        # not whitespace inside a native JSON record or model response.
        return @{exitCode=$process.ExitCode;output=@($stdout.GetAwaiter().GetResult() -split '\r?\n');diagnostics=$stderr.GetAwaiter().GetResult()}
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true) }
        $process.Dispose()
    }
}

function Resolve-MRPhaseProfile {
    param([Parameter(Mandatory)][hashtable] $Config, [Parameter(Mandatory)][hashtable] $Phase, [Parameter(Mandatory)][string] $RoutingRoot, [Parameter(Mandatory)][string] $ProjectRoot, [string]$ExecutionRoot='')
    Assert-MRValue ($Phase.ContainsKey('routingRequirements') -and $Phase.routingRequirements -is [hashtable]) 'Explicit routingRequirements required for each dynamic phase.'
    Assert-MRValue ($Phase.routingRequirements.command -ceq $Phase.command -and $Phase.routingRequirements.role -ceq $Phase.routingRole) 'Phase identity/requirements mismatch.'
    $family=[string]$Config.harness.family
    [void](Get-MRContextHash $Config.context $ProjectRoot -ExecutionRoot $ExecutionRoot)
    Assert-MRValue ($script:MRExecutables.ContainsKey($family)) 'Unknown explicit harness.'
    $lines=@(& $script:MRExecutables[$family] --version 2>&1)
    Assert-MRValue ($LASTEXITCODE -eq 0 -and $lines.Count -gt 0) 'Current harness version unavailable.'
    $decision=Resolve-MRSelection -Config $Config -Requirements $Phase.routingRequirements -Catalog (Get-MRCatalog $RoutingRoot) -Harness $family -HarnessVersion ([string]$lines[0]) -ProjectRoot $ProjectRoot
    Assert-MRValue ($decision.status -eq 'Aligned' -and -not $decision.scriptOnly) "$($decision.status): $($decision.reason)"
    Assert-MRValue $decision.profile.nativeConformanceVerified 'Native model/effort output conformance has no reviewed evidence: do not spend an access probe on an unverified adapter.'
    return @{name="dynamic:$($decision.selection.candidateId)";data=$decision.profile;selection=$decision.selection}
}

Export-ModuleMember -Function Get-MRSha256, Read-MRDocument, Get-MRCatalog, Get-MRContextHash, Get-MRAdapterProfile, Resolve-MRSelection, Test-MRExecutionIdentity, Get-MRNativeReceipt, Invoke-MRBoundedProcess, Resolve-MRPhaseProfile
