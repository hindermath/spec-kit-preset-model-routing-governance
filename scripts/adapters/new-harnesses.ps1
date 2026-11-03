#Requires -Version 7.0
<#
.SYNOPSIS
    DE: Additive Modelladapter. EN: Additive model adapters.
.DESCRIPTION
    DE: Vom Resolver geladen; keine eigenstaendigen Aktionen. Discovery liest
    Metadaten, Auswahl blockiert unbekannte/mehrdeutige Modelle. Keine Installation.
    EN: Loaded by the resolver; no standalone actions. Discovery reads metadata,
    selection blocks unknown/ambiguous models. Never installs dependencies.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-MRNewCli {
    param([string] $Family)
    $executable = [string] $script:Harnesses[$Family].executable
    $arguments = if ($Family -eq 'OpenCode') { @('run', '--help') } else { @('--help') }
    $text = @(& $executable @arguments 2>&1) -join "`n"
    Assert-MRCondition ($LASTEXITCODE -eq 0) 'CLI capability check failed.'
    $required = switch ($Family) {
        Claude { @('--model', '--effort', '--permission-mode', '--tools', '--strict-mcp-config', '--mcp-config', '--no-session-persistence', '--print') }
        Copilot { @('--model', '--effort', '--available-tools', '--deny-tool', '--disable-builtin-mcps', '--no-auto-update', '--no-ask-user', '--prompt') }
        OpenCode { @('--model', '--variant', '--agent') }
    }
    foreach ($flag in $required) {
        Assert-MRCondition ($text.Contains($flag)) "${Family}: CLI interface unsupported; required flag $flag missing."
    }
}

function Invoke-MRSdkDiscovery {
    param([string] $Family)
    Assert-MRCondition ([IO.Path]::IsPathFullyQualified($SdkModulePath) -and
        (Test-Path -LiteralPath $SdkModulePath -PathType Leaf)) 'SDK-Einstieg fehlt / SDK entry missing: -SdkModulePath (absolute local file).'
    $node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue
    Assert-MRCondition ($null -ne $node) 'Node.js fehlt / Node.js missing.'
    $start = [Diagnostics.ProcessStartInfo]::new($node.Source)
    foreach ($argument in @((Join-Path $PSScriptRoot 'discover-sdk.mjs'), $Family,
        $SdkModulePath, (Get-Command $script:Harnesses[$Family].executable -CommandType Application).Source)) {
        $start.ArgumentList.Add($argument)
    }
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(25000)) {
            $process.Kill($true)
            throw 'SDK discovery timeout; blocked.'
        }
        # Never include vendor stderr: it can contain credentials or private paths.
        $text = $stdout.GetAwaiter().GetResult()
        $null = $stderr.GetAwaiter().GetResult()
        Assert-MRCondition ($process.ExitCode -eq 0 -and $text.Length -le 4MB) 'SDK discovery failed; check SDK/CLI compatibility and authentication.'
        try { return $text | ConvertFrom-Json -AsHashtable -Depth 50 }
        catch { throw 'SDK metadata JSON invalid; vendor output suppressed.' }
    } finally { $process.Dispose() }
}

function Invoke-MROpenCodeDiscovery {
    Assert-MRCondition (-not [string]::IsNullOrWhiteSpace($OpenCodeProvider)) '-OpenCodeProvider is required; no implicit provider selection.'
    $uri = $null
    Assert-MRCondition ([uri]::TryCreate($OpenCodeServerUrl, [UriKind]::Absolute, [ref]$uri)) 'OpenCode server URL missing or invalid.'
    Assert-MRCondition ($uri.Scheme -ceq 'http' -and $uri.Host -in @('127.0.0.1', '[::1]') -and
        $uri.AbsolutePath -ceq '/' -and -not $uri.UserInfo -and -not $uri.Query -and -not $uri.Fragment) 'OpenCode requires an explicit HTTP loopback origin without credentials/path/query.'
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $handler.UseProxy = $false
    $client = [Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(15)
    try {
        if ($env:OPENCODE_SERVER_PASSWORD) {
            $username = if ($env:OPENCODE_SERVER_USERNAME) { $env:OPENCODE_SERVER_USERNAME } else { 'opencode' }
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${username}:$($env:OPENCODE_SERVER_PASSWORD)"))
            $client.DefaultRequestHeaders.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Basic', $encoded)
        }
        $response = $client.GetAsync([uri]::new($uri, 'provider'), [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        try {
            Assert-MRCondition $response.IsSuccessStatusCode 'OpenCode provider metadata unavailable; check local server/authentication.'
            $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $memory = [IO.MemoryStream]::new()
            try {
                $buffer = [byte[]]::new(8192)
                $cancel = [Threading.CancellationTokenSource]::new(15000)
                try {
                    while (($count = $stream.ReadAsync($buffer, 0, $buffer.Length, $cancel.Token).GetAwaiter().GetResult()) -gt 0) {
                        Assert-MRCondition (($memory.Length + $count) -le 4MB) 'OpenCode metadata exceeds limit.'
                        $memory.Write($buffer, 0, $count)
                    }
                } finally { $cancel.Dispose() }
                $data = [Text.Encoding]::UTF8.GetString($memory.ToArray()) | ConvertFrom-Json -AsHashtable -Depth 50
            } finally { $memory.Dispose(); $stream.Dispose() }
        } finally { $response.Dispose() }
        Assert-MRCondition ($data.connected -is [object[]] -and $OpenCodeProvider -cin $data.connected) 'Selected OpenCode provider is not connected.'
        $providers = @($data.all | Where-Object { $_.id -ceq $OpenCodeProvider })
        Assert-MRCondition ($providers.Count -eq 1 -and $providers[0].models -is [hashtable]) 'OpenCode provider metadata is ambiguous or unsupported.'
        return @{ models = @($providers[0].models.Values); provider = $OpenCodeProvider }
    } catch {
        throw 'OpenCode metadata discovery blocked; check loopback server, selected provider, authentication and API shape.'
    } finally { $client.Dispose() }
}

function Invoke-MRNewDiscovery {
    param([string] $Family)
    $data = if ($Family -eq 'OpenCode') { Invoke-MROpenCodeDiscovery } else { Invoke-MRSdkDiscovery $Family }
    return @(ConvertTo-MRDiscoveredModel $Family $data)
}

function ConvertTo-MRDiscoveredModel {
    param([string] $Family, [hashtable] $Data)
    Assert-MRCondition ($Data.models -is [object[]] -and $Data.models.Count -gt 0 -and $Data.models.Count -le 4096) 'Empty, oversized or unsupported model inventory.'
    $seen = @{}
    foreach ($item in $Data.models) {
        Assert-MRCondition ($item -is [hashtable]) 'Malformed model metadata.'
        $efforts = @()
        $defaultOnly = $false
        if ($Family -eq 'Claude') {
            $id = [string] $item.value
            if ($item.ContainsKey('supportsEffort') -and $item.supportsEffort -is [bool]) {
                if ($item.supportsEffort -and $item.ContainsKey('supportedEffortLevels')) { $efforts = @($item.supportedEffortLevels) }
                elseif (-not $item.supportsEffort) { $defaultOnly = $true }
            }
        } elseif ($Family -eq 'Copilot') {
            $id = [string] $item.id
            # Unknown policy is not permission. Do not infer enablement from list membership.
            if (-not $item.ContainsKey('policy') -or $item.policy -isnot [hashtable] -or
                -not $item.policy.ContainsKey('state') -or $item.policy.state -cne 'enabled') { continue }
            if ($item.ContainsKey('capabilities') -and $item.capabilities -is [hashtable] -and
                $item.capabilities.ContainsKey('supports') -and $item.capabilities.supports -is [hashtable] -and
                $item.capabilities.supports.ContainsKey('reasoningEffort')) {
                $supports = $item.capabilities.supports.reasoningEffort
                if ($supports -is [bool] -and $supports -and $item.ContainsKey('supportedReasoningEfforts')) { $efforts = @($item.supportedReasoningEfforts) }
                elseif ($supports -is [bool] -and -not $supports) { $defaultOnly = $true }
            }
        } else {
            Assert-MRCondition ($Data.provider -is [string] -and $Data.provider -cmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') 'OpenCode provider missing/invalid.'
            Assert-MRCondition ([string] $item.id -cmatch '^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,199}(?:\[1m\])?$') 'Invalid OpenCode model identifier.'
            $id = "$($Data.provider)/$($item.id)"
            if ($item.ContainsKey('capabilities') -and $item.capabilities -is [hashtable] -and
                $item.capabilities.ContainsKey('reasoning') -and $item.capabilities.reasoning -is [bool]) {
                if (-not $item.capabilities.reasoning) { $defaultOnly = $true }
                elseif ($item.ContainsKey('variants') -and $item.variants -is [hashtable]) { $efforts = @($item.variants.Keys) }
            }
        }
        # Documented extended-context entries may coexist with the base aliases.
        # Inventory them without making them an implicit selection or shell syntax.
        Assert-MRCondition ($id -cmatch '^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,199}(?:\[1m\])?$') 'Invalid model identifier.'
        # These are switching/default policies, not an exact model binding.
        if ($Family -ne 'OpenCode' -and $id -cin @('default', 'auto', 'opusplan')) { continue }
        Assert-MRCondition (-not $seen.ContainsKey($id)) 'Duplicate model identifier; discovery is ambiguous.'
        $seen[$id] = $true
        $accepted = @($efforts | Where-Object { $_ -is [string] -and $_ -cin @('low','medium','high','xhigh','max') } | Sort-Object -Unique)
        [ordered]@{ model = $id; efforts = $accepted; defaultOnly = $defaultOnly }
    }
}

function Get-MRAdapterEffort {
    param([hashtable] $Model, [string] $Role)
    if ($Role -eq 'frontier') {
        if ('high' -cin $Model.efforts) { return 'high' }
        return ''
    }
    foreach ($effort in @('medium', 'low')) {
        if ($effort -cin $Model.efforts) { return $effort }
    }
    if ($Model.defaultOnly) { return 'default' }
    # Fast tasks may reuse an expensive model; never invent a lower effort.
    foreach ($effort in @('high', 'xhigh', 'max')) {
        if ($effort -cin $Model.efforts) { return $effort }
    }
    return ''
}

function Select-MRAdapterCandidate {
    param([string] $Family, [string] $Role, [object[]] $Models, [object[]] $Rules, [string] $ExplicitModel, [hashtable] $FallbackModel)
    $eligible = @($Models | Where-Object { (Get-MRAdapterEffort $_ $Role) -ne '' })
    Assert-MRCondition ($eligible.Count -gt 0) "${Family}: $Role has no model with confirmed required reasoning metadata."
    if ($ExplicitModel) {
        $candidates = @($eligible | Where-Object { $_.model -ceq $ExplicitModel })
        Assert-MRCondition ($candidates.Count -eq 1) "${Family}: explicit $Role model is not an eligible discovered model."
        return $candidates[0]
    }
    foreach ($rule in $Rules) {
        if ($rule.name -ceq 'reuse-frontier') {
            Assert-MRCondition ($null -ne $FallbackModel -and (Get-MRAdapterEffort $FallbackModel $Role) -ne '') "${Family}: no eligible frontier model to reuse."
            return $FallbackModel
        }
        $candidates = @($eligible | Where-Object {
            $name = if ($Family -eq 'OpenCode') { ($_.model -split '/', 2)[1] } else { $_.model }
            # A larger context can change cost; require an explicit exact choice.
            $name -cnotmatch '\[1m\]$' -and $name -cmatch $rule.pattern
        })
        if ($candidates.Count -eq 0) { continue }
        $flag = if ($Role -eq 'frontier') { '-FrontierModel' } else { '-FastModel' }
        $ids = @($candidates | ForEach-Object { $_.model } | Sort-Object -CaseSensitive) -join ', '
        Assert-MRCondition ($candidates.Count -eq 1) "${Family}: $Role rule '$($rule.name)' is ambiguous: $ids. Specify $flag with an exact discovered ID."
        return $candidates[0]
    }
    throw "${Family}: no $Role candidate matched selection policy."
}

function Select-MRDiscoveredModel {
    param([string] $Family, [AllowEmptyCollection()][object[]] $Models)
    $policy = Read-MRJson (Join-Path $PSScriptRoot 'selection-policy.json')
    $frontier = Select-MRAdapterCandidate $Family 'frontier' $Models $policy.roles.frontier $FrontierModel
    $fast = Select-MRAdapterCandidate $Family 'fast' $Models $policy.roles.fast $FastModel $frontier
    return @{
        frontier = $frontier; fast = $fast
        frontierEffort = Get-MRAdapterEffort $frontier 'frontier'
        fastEffort = Get-MRAdapterEffort $fast 'fast'
    }
}

function New-MRAdapterProfile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Returns an in-memory profile only; the resolver owns ShouldProcess and persistence.')]
    [CmdletBinding()]
    param([string] $Family, [string] $Role, [hashtable] $Model, [string] $Effort)
    $readOnly = $Role -eq 'fast-mechanical'
    $effortArgs = if ($Effort -eq 'default') { @() } elseif ($Family -eq 'OpenCode') { @('--variant', '{reasoningEffort}') } else { @('--effort', '{reasoningEffort}') }
    $resultInstruction = 'Return the machine-readable autonomous phase result as the only standard-output content. Use autonomous-phase-result-template.json. Do not write files.'
    switch ($Family) {
        Claude {
            $common = @('--print', '--no-session-persistence', '--model', '{model}') + $effortArgs
            $preflight = $common + @('--permission-mode', 'plan', '--tools', '', '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}', 'Reply exactly MODEL_READY without using tools.')
            $mode = if ($readOnly) { 'plan' } else { 'acceptEdits' }
            $harnessArguments = $common + @('--permission-mode', $mode, ('{prompt}' + "`n`n" + $resultInstruction))
        }
        Copilot {
            $common = @('--model', '{model}', '--no-auto-update', '--no-ask-user') + $effortArgs
            $preflight = $common + @('--available-tools', 'view', '--deny-tool', 'write,shell', '--disable-builtin-mcps', '--prompt', 'Reply exactly MODEL_READY without using tools.')
            $harnessArguments = $common + $(if ($readOnly) { @('--available-tools', 'view', '--deny-tool', 'write,shell', '--disable-builtin-mcps') } else { @() }) + @('--prompt', ('{prompt}' + "`n`n" + $resultInstruction))
        }
        OpenCode {
            $common = @('run', '--model', '{model}') + $effortArgs
            $preflight = $common + @('--agent', 'plan', 'Reply exactly MODEL_READY without using tools.')
            $mode = if ($readOnly) { 'plan' } else { 'build' }
            $harnessArguments = $common + @('--agent', $mode, ('{prompt}' + "`n`n" + $resultInstruction))
        }
    }
    $executable = [string] $script:Harnesses[$Family].executable
    # Repository-relative canonical path keeps root/preset resolution byte-identical.
    $resultAdapter = '.specify/presets/model-routing-governance/scripts/adapters/invoke-harness-with-result.ps1'
    $arguments = @('-NoProfile', '-File', $resultAdapter, '-OutputFile', '{outputFile}', '-Executable', $executable, '--') + $harnessArguments
    return [ordered]@{
        routingRole = $Role; agentFamily = $Family; model = $Model.model
        reasoningEffort = $Effort; executable = 'pwsh'
        preflight = [ordered]@{ executable = $executable; arguments = $preflight }
        arguments = $arguments
    }
}
