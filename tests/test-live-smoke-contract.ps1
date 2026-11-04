#Requires -Version 7.3
<#
.SYNOPSIS
    DE: Prueft den Live-Smoke-Test offline. EN: Verifies the live smoke test offline.
.DESCRIPTION
    DE: Verwendet nur temporaere PowerShell-Kindprozesse und synthetische
    Profile. Keine Harnesses, Modelle, Konten oder Netzwerkzugriffe.
    EN: Uses only temporary PowerShell child processes and synthetic profiles.
    No harnesses, models, accounts or network access.
.EXAMPLE
    pwsh -NoProfile -File tests/test-live-smoke-contract.ps1
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$liveRoot = Join-Path $PSScriptRoot 'live'
$temporary = Join-Path ([IO.Path]::GetTempPath()) "model-routing-smoke-contract-$([guid]::NewGuid().ToString('N'))"
$script:checks = 0
function Assert-SmokeContract {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw "Live smoke contract: $Message" }
    $script:checks++
}
try {
    [void](New-Item -ItemType Directory -Path $temporary)
    Import-Module (Join-Path $liveRoot 'model-routing-smoke-core.psm1') -Force
    $defaultsPath = Join-Path $liveRoot 'model-routing-smoke.defaults.json'
    $childScript = Join-Path $liveRoot 'invoke-smoke-child.ps1'
    $configuration = Read-MRSmokeConfiguration $defaultsPath
    Assert-SmokeContract ($configuration.harnesses.Count -eq 5) 'five ordered harnesses'
    Assert-SmokeContract ($configuration.maxRetriesUpperBound -eq 3) 'retry upper bound'
    Assert-SmokeContract ($configuration.sdk.claude.version -ceq '0.3.318' -and $configuration.sdk.copilot.version -ceq '1.0.28') 'pinned SDK versions'
    Assert-SmokeContract ($configuration.task.expectedOutput -ceq 'MODEL_ROUTING_OK') 'exact task output'
    Assert-SmokeContract (Test-MRSmokeRequired @('scripts/adapters/new-harnesses.ps1') $configuration.triggerPaths) 'adapter change requires smoke test'
    Assert-SmokeContract (Test-MRSmokeRequired @('tests/live/model-routing-smoke.defaults.json') $configuration.triggerPaths) 'matrix change requires smoke test'
    Assert-SmokeContract (-not (Test-MRSmokeRequired @('docs/user-guide.md') $configuration.triggerPaths)) 'documentation-only change does not require smoke test'
    $ignored = @(& git -C $root check-ignore '.test-results/model-routing-smoke/fixture.json' 'tests/live/model-routing-smoke.local.json')
    Assert-SmokeContract ($LASTEXITCODE -eq 0 -and $ignored.Count -eq 2) 'local report and selection paths are git-ignored'

    $overridePath = Join-Path $temporary 'selection.json'
    @{schemaVersion='1.0';selections=@{Copilot=@{frontierModel='fixture-frontier';fastModel='fixture-fast'}}} | ConvertTo-Json -Depth 10 | Set-Content $overridePath
    $overridden = Merge-MRSmokeSelectionOverride $configuration $overridePath
    $copilot = @($overridden.harnesses | Where-Object family -ceq 'Copilot')[0]
    Assert-SmokeContract ($copilot.frontierModel -ceq 'fixture-frontier' -and $copilot.fastModel -ceq 'fixture-fast') 'local exact-selection override'

    $argumentFixture = Join-Path $temporary 'argument-fixture.ps1'
    @'
[CmdletBinding()]
param([Parameter(Mandatory)][AllowEmptyString()][string] $Value)
"$($PWD.Path)|$env:PWD|$($Value.Length)"
'@ | Set-Content $argumentFixture
    $working = Join-Path $temporary 'working directory'
    [void](New-Item -ItemType Directory -Path $working)
    $child = Invoke-MRSmokeProcess -ChildScript $childScript -Executable 'pwsh' `
        -Arguments @('-NoProfile','-File',$argumentFixture,'') -WorkingDirectory $working -TimeoutSeconds 10
    $parts = $child.stdout.Trim() -split '\|'
    Assert-SmokeContract ($child.exitCode -eq 0 -and $parts.Count -eq 3) 'JSON child argument transport'
    $workingSuffix = $working.Substring($temporary.Length)
    Assert-SmokeContract ($parts[0].EndsWith($workingSuffix,[StringComparison]::Ordinal) -and
        $parts[1] -ceq $working -and $parts[2] -ceq '0') 'PWD and empty argument preservation'
    $env:MODEL_ROUTING_SMOKE_TEST_SECRET = 'must-not-reach-child'
    try {
        $startInfo = New-MRSmokeProcessStartInfo -ChildScript $childScript -Executable 'pwsh' -Arguments @('-NoProfile') `
            -WorkingDirectory $working -RemovedEnvironment @('MODEL_ROUTING_SMOKE_TEST_SECRET')
        Assert-SmokeContract (-not $startInfo.Environment.ContainsKey('MODEL_ROUTING_SMOKE_TEST_SECRET')) 'sensitive child environment removal'
    } finally { Remove-Item Env:MODEL_ROUTING_SMOKE_TEST_SECRET -ErrorAction SilentlyContinue }

    $sentinel = Join-Path $temporary 'forbidden-sentinel.txt'
    $grandchild = Join-Path $temporary 'grandchild.ps1'
    "Start-Sleep -Seconds 2; Set-Content -LiteralPath '$($sentinel.Replace("'","''"))' -Value forbidden" | Set-Content $grandchild
    $parent = Join-Path $temporary 'parent.ps1'
    "`$process = Start-Process pwsh -ArgumentList @('-NoProfile','-File','$($grandchild.Replace("'","''"))') -PassThru; Start-Sleep -Seconds 10" | Set-Content $parent
    $timedOut = $false
    try {
        $null = Invoke-MRSmokeProcess -ChildScript $childScript -Executable 'pwsh' -Arguments @('-NoProfile','-File',$parent) `
            -WorkingDirectory $working -TimeoutSeconds 0.5
    } catch { $timedOut = $_.Exception.Message -like 'TIMEOUT:*' }
    Start-Sleep -Seconds 3
    Assert-SmokeContract $timedOut 'bounded process timeout'
    Assert-SmokeContract (-not (Test-Path $sentinel)) 'timeout kills the descendant process tree'

    $baseProfile = @{model='fixture-model';reasoningEffort='high'}
    $agy = $baseProfile.Clone();$agy.arguments=@('--model','{model}','--effort','{reasoningEffort}','--mode','accept-edits','--print','{prompt}')
    $agyArguments = @(Expand-MRSmokeProfileArguments $agy $working (Join-Path $temporary 'agy.json') 'Antigravity' 'fixture prompt')
    Assert-SmokeContract ('--settings' -cin $agyArguments -and $agyArguments[-1] -ceq 'fixture prompt') 'agy session permission and prompt'
    foreach ($family in @('Claude','Copilot','OpenCode')) {
        $runnerProfile = $baseProfile.Clone()
        $harnessArguments = switch ($family) {
            Claude { @('--print','--model','{model}','--permission-mode','acceptEdits','{prompt}') }
            Copilot { @('--model','{model}','--output-format','json','--prompt','{prompt}') }
            OpenCode { @('run','--model','{model}#high','--agent','build','{prompt}') }
        }
        $runnerProfile.arguments = @('-NoProfile','-File','adapter.ps1','-OutputFile','{outputFile}','-HarnessArgumentsJson',(ConvertTo-Json -InputObject $harnessArguments -Compress))
        $expanded = @(Expand-MRSmokeProfileArguments $runnerProfile $working (Join-Path $temporary "$family.json") $family 'fixture prompt')
        $jsonIndex = [Array]::IndexOf([object[]]$expanded,'-HarnessArgumentsJson')
        $decoded = @($expanded[$jsonIndex + 1] | ConvertFrom-Json)
        Assert-SmokeContract ($decoded -ccontains 'fixture prompt') "$family prompt survives JSON transport"
        if ($family -eq 'Claude') { Assert-SmokeContract ('--allowedTools' -cin $decoded -and '--' -cin $decoded) 'Claude session permissions' }
        if ($family -eq 'Copilot') { Assert-SmokeContract ('--trust-folder' -cin $decoded -and '--allow-tool=shell' -cin $decoded) 'Copilot session permissions' }
        if ($family -eq 'OpenCode') { Assert-SmokeContract ('--auto' -cin $decoded) 'OpenCode session permission' }
    }

    Assert-SmokeContract ((Get-MRSmokeFinalStatus @(@{attempt=1;status='PASS'})) -ceq 'PASS') 'first-pass result'
    Assert-SmokeContract ((Get-MRSmokeFinalStatus @(@{attempt=1;status='FAILED'},@{attempt=2;status='PASS'})) -ceq 'PASS_WITH_RETRY') 'retry result'
    Assert-SmokeContract ((Get-MRSmokeFinalStatus @(@{attempt=1;status='BLOCKED'})) -ceq 'BLOCKED') 'blocked result'
    Assert-SmokeContract ((Get-MRSmokeFinalStatus @(@{attempt=1;status='TIMEOUT'})) -ceq 'TIMEOUT') 'timeout result'
    Assert-SmokeContract ((Get-MRSmokeFinalStatus @(@{attempt=1;status='INFRA_ERROR'})) -ceq 'INFRA_ERROR') 'infrastructure result'

    $reportPath = Join-Path $temporary 'report/report.json'
    Write-MRSmokeJsonAtomic -Path $reportPath -Value @{schemaVersion='1.0';finalStatus='PASS'} -Confirm:$false
    $report = Get-Content $reportPath -Raw | ConvertFrom-Json -AsHashtable
    Assert-SmokeContract ($report.schemaVersion -ceq '1.0' -and $report.finalStatus -ceq 'PASS') 'atomic report JSON'

    $gate = Invoke-MRSmokeProcess -ChildScript $childScript -Executable 'pwsh' `
        -Arguments @('-NoProfile','-File',(Join-Path $liveRoot 'invoke-model-routing-smoke.ps1')) `
        -WorkingDirectory $root -TimeoutSeconds 15
    Assert-SmokeContract ($gate.exitCode -ne 0 -and $gate.stderr.Contains('-ConfirmLiveRun')) 'live authorization gate'
    "PASS: $script:checks live-smoke contract assertions; offline."
} finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
