#Requires -Version 7.0
<#
.SYNOPSIS
    Routing-Fixtures ohne Inferenz / Routing fixtures without inference.
.DESCRIPTION
    DE: Isolierte positive/negative Tests; schreibt nur in einen Temp-Ordner.
    EN: Isolated positive/negative tests; only writes in a temporary directory.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/dynamic-model-routing.psm1') -Force
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('routing-fixtures-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temporary)
$script:passed=0
function Assert-Test {
    param([bool]$Condition,[string]$Name)
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:passed++; Write-Output "PASS: $Name"
}
function Copy-TestData {
    param($Data)
    $options=@{AsHashtable=$true}
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $options.DateKind='String' }
    return $Data | ConvertTo-Json -Depth 50 | ConvertFrom-Json @options
}
try {
    $now=[DateTimeOffset]::UtcNow
    $evidenceFile=Join-Path $temporary 'reviewed-evaluation.txt'
    'Synthetic evaluator evidence; not a real model quality result.' | Set-Content -LiteralPath $evidenceFile
    $contextFile=Join-Path $temporary 'account-context.txt'
    'fixture-account/provider' | Set-Content -LiteralPath $contextFile
    $hash=(Get-FileHash $evidenceFile).Hash.ToLowerInvariant()
    $evidence=@{path=$evidenceFile;sha256=$hash;reviewer='fixture-reviewer';reviewedAt=$now.AddHours(-1).ToString('o');expiresAt=$now.AddDays(1).ToString('o')}
    $catalog=@{sha256=('c'*64);commands=@{'speckit.plan'='frontier-reasoning';'speckit.implement'='long-running-implementation';'speckit.status'='fast-mechanical';'speckit.stop'='script-only'}}
    $requirements=@{schemaVersion='1.0';command='speckit.plan';role='frontier-reasoning';complexity='normal';risk='normal';contextTokens=8192;capabilities=@('coding')}
    $candidate=@{id='small-reviewed';model='fixture-one';effort='high';providerContextId='fixture-account';roles=@('frontier-reasoning','coding-review','long-running-implementation','fast-mechanical');complexities=@('simple','normal','challenging');risks=@('low','normal','high');capabilities=@('coding','security','architecture');contextTokens=32768;preferenceRank=1;evidence=$evidence}
    $config=@{schemaVersion='3.0';harness=@{family='Codex';version='fixture-version'};context=@{projectRoot=$temporary;providerContextId='fixture-account';bindings=@(@{path=$contextFile;sha256=(Get-FileHash $contextFile).Hash.ToLowerInvariant()})};
        inventory=@{collectedAt=$now.ToString('o');source=$evidence;models=@(@{id='fixture-one';efforts=@('high')},@{id='fixture-two';efforts=@('high')})};
        policy=@{selectionMode='quality-with-efficiency';fallbackPolicy='fail-closed';approvedBy='fixture-owner';approvedAt=$now.AddMinutes(-1).ToString('o');catalogSha256=$catalog.sha256;maximumInventoryAgeHours=24};candidates=@($candidate)}
    $config.context.bindings=@('account','provider','project' | ForEach-Object { @{kind=$_;path=$contextFile;sha256=(Get-FileHash $contextFile).Hash.ToLowerInvariant()} })
    $config.policy.contextSha256=Get-MRContextHash $config.context $temporary
    function Get-TestPoolHash { param([hashtable]$Data); return Get-MRSha256 ($Data.candidates | ConvertTo-Json -Depth 40 -Compress) }
    $config.policy.candidatesSha256=Get-TestPoolHash $config
    function Get-TestSelection { param([hashtable]$Data=$config,[hashtable]$Phase=$requirements,[string]$Family='Codex',[hashtable]$Contract=$catalog); return Resolve-MRSelection $Data $Phase $Contract $Family 'fixture-version' $temporary -Now $now }
    $before=(Get-FileHash $contextFile).Hash
    $selected=Get-TestSelection
    Assert-Test ($selected.status -eq 'Aligned' -and $selected.selection.model -eq 'fixture-one') 'explicit suitable candidate selected'
    Assert-Test ($selected.selection.access -eq 'NotProbed') 'selection does not claim inference access'
    Assert-Test ((Get-FileHash $contextFile).Hash -eq $before) 'selection is read-only'
    foreach ($family in @('Codex','Claude','Copilot','Antigravity','OpenCode')) {
        $data=Copy-TestData $config; $data.harness.family=$family
        if ($family -eq 'OpenCode') {
            $data.candidates[0].model='fixture/one'; $data.candidates[0].variant='deep'
            $data.inventory.models=@(@{id='fixture/one';efforts=@('high');variants=@(@{id='deep';effort='high'})})
        }
        $data.policy.candidatesSha256=Get-TestPoolHash $data
        $out=Get-TestSelection $data -Family $family
        if ($out.status -ne 'Aligned') { Write-Output ($out | ConvertTo-Json -Depth 10) }
        Assert-Test ($out.status -eq 'Aligned' -and $out.profile.agentFamily -eq $family) "$family shares the same selection engine"
        Assert-Test (@($out.profile.arguments | Where-Object {$_ -match 'dangerously|allow-all|--auto'}).Count -eq 0) "$family has no permission bypass"
        if ($family -eq 'Claude') {
            $modeIndex=[Array]::IndexOf([object[]]$out.profile.arguments,'--permission-mode')
            Assert-Test ($modeIndex -ge 0 -and $out.profile.arguments[$modeIndex+1] -ceq 'manual' -and $out.profile.arguments -contains '--permission-prompts' -and $out.profile.arguments -contains 'none') 'Claude uses documented manual mode with unattended prompts denied'
        }
    }
    $data=Copy-TestData $config; $data.inventory.collectedAt=$now.AddHours(-25).ToString('o')
    Assert-Test ((Get-TestSelection $data).status -eq 'RefreshRequired') 'expired inventory'
    $data=Copy-TestData $config; $data.inventory.collectedAt=$now.AddHours(1).ToString('o')
    Assert-Test ((Get-TestSelection $data).status -eq 'RefreshRequired') 'future inventory'
    $data=Copy-TestData $config; $data.harness.version='different'
    Assert-Test ((Get-TestSelection $data).status -eq 'Blocked') 'harness version drift'
    Assert-Test ((Get-TestSelection $config -Family Claude).status -eq 'Blocked') 'no harness switching'
    $data=Copy-TestData $config; $data.context.providerContextId='other-account'
    Assert-Test ((Get-TestSelection $data).status -eq 'Blocked') 'account scope drift'
    $data=Copy-TestData $config; $data.policy.catalogSha256='bad'
    Assert-Test ((Get-TestSelection $data).status -eq 'Blocked') 'catalog drift'
    $data=Copy-TestData $config; $data.candidates[0].preferenceRank=0
    Assert-Test ((Get-TestSelection $data).status -eq 'Blocked') 'unapproved pool changes'
    $data=Copy-TestData $config; $data.inventory.models=@()
    Assert-Test ((Get-TestSelection $data).status -eq 'NeedsClarification') 'removed model'
    $data=Copy-TestData $config; $data.inventory.models[0].efforts=@('medium')
    Assert-Test ((Get-TestSelection $data).status -eq 'NeedsClarification') 'unsupported effort'
    $data=Copy-TestData $config; $data.candidates[0].contextTokens=1; $data.policy.candidatesSha256=Get-TestPoolHash $data
    Assert-Test ((Get-TestSelection $data).status -eq 'NeedsClarification') 'context too small'
    $phase=Copy-TestData $requirements; $phase.Remove('risk')
    Assert-Test ((Get-TestSelection -Phase $phase).status -eq 'Blocked') 'missing risk cannot downgrade'
    $phase=Copy-TestData $requirements; $phase.role='fast-mechanical'
    Assert-Test ((Get-TestSelection -Phase $phase).status -eq 'Blocked') 'strongest role cannot downgrade'
    $data=Copy-TestData $config; $data.candidates[0].complexities=@('simple','normal'); $data.policy.candidatesSha256=Get-TestPoolHash $data
    $phase=Copy-TestData $requirements; $phase.risk='high'; $phase.complexity='simple'
    Assert-Test ((Get-TestSelection $data $phase).status -eq 'NeedsClarification') 'high risk enforces challenging floor'
    $phase=Copy-TestData $requirements; $phase.capabilities=@('security'); $phase.complexity='simple'
    Assert-Test ((Get-TestSelection $data $phase).status -eq 'NeedsClarification') 'security enforces challenging floor'
    $data=Copy-TestData $config; $other=Copy-TestData $data.candidates[0]; $other.id='larger'; $other.model='fixture-two'; $other.preferenceRank=2; $data.candidates+=@($other); $data.policy.candidatesSha256=Get-TestPoolHash $data
    Assert-Test ((Get-TestSelection $data).selection.candidateId -eq 'small-reviewed') 'smallest approved suitable preference wins'
    $data.candidates[1].preferenceRank=1; $data.policy.candidatesSha256=Get-TestPoolHash $data
    Assert-Test ((Get-TestSelection $data).status -eq 'NeedsClarification') 'tie never resolved by name or ordering'
    $data.candidates[1].id=$data.candidates[0].id; $data.policy.candidatesSha256=Get-TestPoolHash $data
    Assert-Test ((Get-TestSelection $data).status -eq 'Blocked') 'duplicate IDs block'
    $data=Copy-TestData $config; $data.candidates[0].evidence.sha256='bad'; $data.policy.candidatesSha256=Get-TestPoolHash $data
    Assert-Test ((Get-TestSelection $data).status -ne 'Aligned') 'evidence tamper'
    $data=Copy-TestData $config; $data.candidates[0].evidence.expiresAt=$now.AddSeconds(-1).ToString('o'); $data.policy.candidatesSha256=Get-TestPoolHash $data
    Assert-Test ((Get-TestSelection $data).status -ne 'Aligned') 'evidence expiry'
    Assert-Test ((Get-TestSelection @{schemaVersion='2.0'}).status -eq 'RefreshRequired') 'legacy profile not silently migrated'
    Assert-Test ((Get-TestSelection @{} -Family OpenCode).status -eq 'NotConfigured') 'optional OpenCode unconfigured'
    $phase=@{schemaVersion='1.0';command='speckit.stop';role='script-only';complexity='simple';risk='low';contextTokens=0;capabilities=@()}
    $stop=Get-TestSelection -Phase $phase
    Assert-Test ($stop.scriptOnly -and -not $stop.ContainsKey('profile')) 'script-only never renders a model process'
    $receipt=@{source='harness-metadata';fallbackOccurred=$false}
    foreach ($key in @('harness','model','effort','contextSha256','policySha256','inventorySha256')) { $receipt[$key]=$selected.selection[$key] }
    Test-MRExecutionIdentity $receipt $selected.selection
    Assert-Test $true 'exact execution identity receipt accepted'
    $receipt.model='unexpected-model'; $caught=$false
    try {Test-MRExecutionIdentity $receipt $selected.selection} catch {$caught=$true}
    Assert-Test $caught 'actual model mismatch/fallback blocked'
    foreach ($family in @('Codex','Claude','Copilot','Antigravity','OpenCode')) {
        $selection=Copy-TestData $selected.selection; $selection.harness=$family
        $nativeEvent=switch ($family) {
            Codex {@{type='thread.started';model=$selection.model;reasoning_effort=$selection.effort}}
            Claude {@{type='system';subtype='init';model=$selection.model;effort=$selection.effort}}
            Copilot {@{type='session.start';data=@{selectedModel=$selection.model;reasoningEffort=$selection.effort}}}
            Antigravity {@{type='system';model=$selection.model;effort=$selection.effort}}
            OpenCode {@{type='session.created';model=$selection.model;effort=$selection.effort}}
        }
        $nativeEvent.fallbackOccurred=$false
        $native=Get-MRNativeReceipt -Output @(($nativeEvent | ConvertTo-Json -Depth 10 -Compress)) -Selection $selection
        Test-MRExecutionIdentity $native $selection
        Assert-Test $true "$family synthetic native metadata contract"
    }
    $caught=$false
    try { Get-MRNativeReceipt -Output @('{"type":"assistant","content":"MODEL_READY"}') -Selection $selected.selection } catch {$caught=$true}
    Assert-Test $caught 'assistant text cannot forge native identity'
    $caught=$false
    try { Get-MRNativeReceipt -Output @('{"type":"thread.started","model":"other","reasoning_effort":"high"}') -Selection $selected.selection } catch {$caught=$true}
    Assert-Test $caught 'native fallback model rejected'
    $caught=$false
    try {Get-MRNativeReceipt -Output @('{"type":"thread.started","model":"fixture-one","reasoning_effort":"high"}') -Selection $selected.selection} catch {$caught=$true}
    Assert-Test $caught 'missing native no-fallback evidence blocks'
    $probeProfile=@{executable=(Get-Process -Id $PID).Path;arguments=@('-NoProfile','-Command','Write-Output "fixture-only"')}
    # Healthy launch uses the production preflight budget, including cold
    # PowerShell startup. The independent negative timeout remains one second.
    $probe=Invoke-MRBoundedProcess $probeProfile @{} $temporary -TimeoutSeconds 120
    Assert-Test ($probe.exitCode -eq 0 -and $probe.output -contains 'fixture-only') 'bounded subprocess argument-vector path'
    $probeProfile.arguments=@('-NoProfile','-Command','[Console]::Write("fixture-crlf`r`nsecond`r`n")')
    $probe=Invoke-MRBoundedProcess $probeProfile @{} $temporary -TimeoutSeconds 120
    Assert-Test ($probe.exitCode -eq 0 -and $probe.output -contains 'fixture-crlf' -and $probe.output -contains 'second') 'native CRLF output preserves exact logical records'
    $probeProfile.arguments=@('--version')
    $probe=Invoke-MRBoundedProcess $probeProfile @{} $temporary -TimeoutSeconds 120
    Assert-Test ($probe.exitCode -eq 0 -and ($probe.output -join ' ') -match '^PowerShell ') 'single-argument metadata vector preserved'
    $probeProfile.arguments=@('-NoProfile','-Command','Start-Sleep -Seconds 10')
    $probe=Invoke-MRBoundedProcess $probeProfile @{} $temporary -TimeoutSeconds 1
    Assert-Test ($probe.exitCode -eq 124) 'preflight timeout stops process without retry'
    # CLI tests shadow only the version probe; inference would throw.
    function codex { if ($args.Count -eq 1 -and $args[0] -eq '--version') { $global:LASTEXITCODE=0; 'fixture-version' } else {throw 'Inference forbidden in fixture'} }
    $resolver=Join-Path $PSScriptRoot '../scripts/resolve-model-routing.ps1'
    $catalogRoot=Join-Path $temporary 'catalog'; [void](New-Item -ItemType Directory -Path $catalogRoot)
    @{schemaVersion='1.0';presetId='fixture';fallbackPolicy='fail-closed';defaultRole='frontier-reasoning';commands=$catalog.commands} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $catalogRoot 'model-routing.json')
    $cliConfig=Copy-TestData $config; $cliConfig.policy.catalogSha256=(Get-MRCatalog $catalogRoot).sha256
    $draft=Join-Path $temporary 'draft.json'; $target=Join-Path $temporary 'local.json'; $phasePath=Join-Path $temporary 'phase.json'
    $cliConfig | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $draft
    $requirements | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $phasePath
    $legacy='{"schemaVersion":"2.0","profiles":{}}'; $legacy | Set-Content -LiteralPath $target
    $before=(Get-FileHash $target).Hash
    $null=& $resolver -Action Status -Harness Codex -ConfigPath $target -OutputFormat Json
    Assert-Test ($LASTEXITCODE -eq 2 -and (Get-FileHash $target).Hash -eq $before) 'legacy status exit 2 without migration'
    $null=& $resolver -Action Refresh -Harness Codex -ConfigPath $target -InputConfig $draft -RequirementsPath $phasePath -RoutingRoot $catalogRoot -ProjectRoot $temporary -OutputFormat Json
    Assert-Test ($LASTEXITCODE -eq 3 -and (Get-FileHash $target).Hash -eq $before) 'refresh without authority cannot write'
    $null=& $resolver -Action Refresh -Harness Codex -ConfigPath $target -InputConfig $draft -RequirementsPath $phasePath -RoutingRoot $catalogRoot -ProjectRoot $temporary -ApproveLocalRefresh -WhatIf -OutputFormat Json
    Assert-Test ($LASTEXITCODE -eq 0 -and (Get-FileHash $target).Hash -eq $before) 'refresh WhatIf validates without writes'
    $null=& $resolver -Action Refresh -Harness Codex -ConfigPath $target -InputConfig $draft -RequirementsPath $phasePath -RoutingRoot $catalogRoot -ProjectRoot $temporary -ApproveLocalRefresh -OutputFormat Json
    Assert-Test ($LASTEXITCODE -eq 0 -and (Read-MRDocument $target).schemaVersion -eq '3.0') 'explicit isolated refresh persists schema 3'
    $before=(Get-FileHash $target).Hash
    $preview=& $resolver -Action Preview -Harness Codex -ConfigPath $target -RequirementsPath $phasePath -RoutingRoot $catalogRoot -ProjectRoot $temporary -OutputFormat Json
    if ($LASTEXITCODE -ne 0) { Write-Output $preview }
    Assert-Test ($LASTEXITCODE -eq 0 -and (Get-FileHash $target).Hash -eq $before) 'Preview read-only exit 0'
    $null=& $resolver -Action Status -Harness Auto -ConfigPath $target -OutputFormat Json
    Assert-Test ($LASTEXITCODE -eq 4) 'Auto requires explicit harness decision'
    & (Get-Module dynamic-model-routing) {
        function script:codex { if ($args.Count -eq 1 -and $args[0] -eq '--version') { $global:LASTEXITCODE=0; 'fixture-version' } else {throw 'Inference forbidden in module fixture'} }
    }
    $phase=@{command=$requirements.command;routingRole=$requirements.role;routingRequirements=$requirements}
    $caught=$false
    try {Resolve-MRPhaseProfile -Config $cliConfig -Phase $phase -RoutingRoot $catalogRoot -ProjectRoot $temporary} catch {$caught=$_.Exception.Message -like 'Native model/effort output conformance*'}
    Assert-Test $caught 'runner blocks unproved native conformance before access probe'
    $cliConfig.candidates[0].capabilities+=@('native-model-effort-acknowledgement')
    $cliConfig.policy.candidatesSha256=Get-TestPoolHash $cliConfig
    $bound=Resolve-MRPhaseProfile -Config $cliConfig -Phase $phase -RoutingRoot $catalogRoot -ProjectRoot $temporary
    Assert-Test ($bound.name -eq 'dynamic:small-reviewed') 'shared phase binder returns reviewed selection'
    $phase.routingRequirements=Copy-TestData $requirements; $phase.routingRequirements.command='speckit.implement'
    $caught=$false
    try {Resolve-MRPhaseProfile -Config $cliConfig -Phase $phase -RoutingRoot $catalogRoot -ProjectRoot $temporary} catch {$caught=$true}
    Assert-Test $caught 'phase command cannot be substituted by requirements'
    $executionRoot=Join-Path $temporary 'worktree'; [void](New-Item -ItemType Directory -Path $executionRoot)
    Copy-Item -LiteralPath $contextFile -Destination (Join-Path $executionRoot 'account-context.txt')
    Assert-Test ((Get-MRContextHash $config.context $temporary -ExecutionRoot $executionRoot) -eq $config.policy.contextSha256) 'isolated worktree configuration parity'
    'different' | Set-Content -LiteralPath (Join-Path $executionRoot 'account-context.txt')
    $caught=$false
    try {Get-MRContextHash $config.context $temporary -ExecutionRoot $executionRoot} catch {$caught=$true}
    Assert-Test $caught 'isolated worktree configuration drift blocks'
    Remove-Item Function:codex
    'changed' | Set-Content -LiteralPath $contextFile
    Assert-Test ((Get-TestSelection).status -eq 'Blocked') 'configuration drift detected from live bytes'
    $activeRoot=Join-Path $temporary 'active-presets'
    foreach ($id in @('strong','weak','.cache')) { [void](New-Item -ItemType Directory -Path (Join-Path $activeRoot $id)) }
    foreach ($id in @('strong','weak')) {
        $role=if($id -eq 'strong'){'frontier-reasoning'}else{'fast-mechanical'}
        @{schemaVersion='1.0';presetId=$id;defaultRole=$role;fallbackPolicy='fail-closed';commands=@{'speckit.plan'=$role}} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $activeRoot "$id/model-routing.json")
    }
    'invalid cached content' | Set-Content -LiteralPath (Join-Path $activeRoot '.cache/model-routing.json')
    $registry=@{presets=@{strong=@{enabled=$false;version='fixture'};weak=@{enabled=$true;version='fixture'}}}
    $registry | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $activeRoot '.registry')
    $active=Get-MRCatalog $activeRoot
    Assert-Test ($active.commands['speckit.plan'] -eq 'fast-mechanical') 'disabled preset and cache cannot raise or shadow roles'
    $registry.presets.strong.enabled=$true
    $registry | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $activeRoot '.registry')
    $enabled=Get-MRCatalog $activeRoot
    Assert-Test ($enabled.commands['speckit.plan'] -eq 'frontier-reasoning' -and $enabled.sha256 -ne $active.sha256) 'enable drift changes catalog hash and strongest role'
    $corpus=Read-MRDocument (Join-Path $PSScriptRoot '../docs/evaluation-cases.json')
    $locked=Read-MRDocument (Join-Path $PSScriptRoot '../docs/evaluation-input-lock.json')
    foreach ($item in $corpus.cases) {
        $expected=@($locked.inputs | Where-Object {$_.id -ceq $item.id})
        Assert-Test ($expected.Count -eq 1 -and $expected[0].inputSha256 -ceq (Get-MRSha256 $item.input)) "frozen evaluation input: $($item.id)"
    }
    Write-Output "RESULT: $script:passed deterministic assertions, no inference, no quality claim."
} finally { Remove-Item -LiteralPath $temporary -Recurse -Force }
exit 0
