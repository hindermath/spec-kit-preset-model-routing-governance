Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-MRSmokeConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    $configuration = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 50
    if ([string] $configuration.schemaVersion -cne '1.0' -or
        [string] $configuration.testId -cne 'model-routing-live-smoke') {
        throw 'Smoke configuration schema or test ID is unsupported.'
    }
    if ($configuration.attemptBudgetSeconds -isnot [long] -or $configuration.attemptBudgetSeconds -lt 1 -or
        $configuration.verificationTimeoutSeconds -isnot [long] -or $configuration.verificationTimeoutSeconds -lt 1 -or
        $configuration.maxRetriesUpperBound -ne 3) {
        throw 'Smoke configuration time or retry limits are invalid.'
    }
    $families = @($configuration.harnesses | ForEach-Object { [string] $_.family })
    if (($families -join ',') -cne 'Antigravity,Claude,Codex,Copilot,OpenCode') {
        throw 'Smoke configuration harness order is invalid.'
    }
    foreach ($name in @('Claude','Copilot','OpenCode')) {
        $entry = @($configuration.harnesses | Where-Object { [string] $_.family -ceq $name })
        if ($entry.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$entry[0].frontierModel) -or
            [string]::IsNullOrWhiteSpace([string]$entry[0].fastModel)) {
            throw "Smoke configuration exact selection is missing for $name."
        }
    }
    if ([string] $configuration.task.framework -cne 'net10.0' -or
        [string] $configuration.task.expectedOutput -cne 'MODEL_ROUTING_OK' -or
        [string]::IsNullOrWhiteSpace([string]$configuration.task.prompt)) {
        throw 'Smoke configuration task contract is invalid.'
    }
    return $configuration
}

function Merge-MRSmokeSelectionOverride {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable] $Configuration, [string] $Path = '')
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Configuration }
    $override = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 20
    if ([string] $override.schemaVersion -cne '1.0' -or $override.selections -isnot [hashtable]) {
        throw 'Local smoke selection override schema is unsupported.'
    }
    $allowed = @('Claude','Copilot','OpenCode')
    foreach ($key in $override.selections.Keys) {
        if ($key -cnotin $allowed) { throw "Unknown local smoke selection family: $key" }
        $selection = [hashtable] $override.selections[$key]
        foreach ($field in @('frontierModel','fastModel')) {
            if ([string]::IsNullOrWhiteSpace([string]$selection[$field])) { throw "$key local override is missing $field." }
        }
        $target = @($Configuration.harnesses | Where-Object { [string] $_.family -ceq $key })[0]
        $target.frontierModel = [string] $selection.frontierModel
        $target.fastModel = [string] $selection.fastModel
        if ($key -eq 'OpenCode' -and $selection.ContainsKey('provider')) {
            if ([string]::IsNullOrWhiteSpace([string]$selection.provider)) { throw 'OpenCode local override provider is empty.' }
            $target.provider = [string] $selection.provider
        }
    }
    return $Configuration
}

function New-MRSmokeProcessStartInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $ChildScript,
        [Parameter(Mandatory)][string] $Executable,
        [Parameter(Mandatory)][AllowEmptyString()][string[]] $Arguments,
        [Parameter(Mandatory)][string] $WorkingDirectory,
        [string[]] $RemovedEnvironment = @(),
        [hashtable] $Environment = @{}
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Process -Id $PID).Path
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @('-NoProfile','-File',$ChildScript,'-Executable',$Executable,'-ArgumentsJson',(ConvertTo-Json -InputObject @($Arguments) -Compress))) {
        [void] $start.ArgumentList.Add($argument)
    }
    foreach ($name in $RemovedEnvironment) { [void] $start.Environment.Remove($name) }
    $start.Environment['PWD'] = $WorkingDirectory
    foreach ($entry in $Environment.GetEnumerator()) { $start.Environment[[string]$entry.Key] = [string]$entry.Value }
    return $start
}

function Invoke-MRSmokeProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $ChildScript,
        [Parameter(Mandatory)][string] $Executable,
        [Parameter(Mandatory)][AllowEmptyString()][string[]] $Arguments,
        [Parameter(Mandatory)][string] $WorkingDirectory,
        [Parameter(Mandatory)][double] $TimeoutSeconds,
        [string[]] $RemovedEnvironment = @(),
        [hashtable] $Environment = @{}
    )
    if ($TimeoutSeconds -le 0) { throw 'TIMEOUT: harness budget exhausted.' }
    $startArguments = @{
        ChildScript = $ChildScript; Executable = $Executable; Arguments = $Arguments
        WorkingDirectory = $WorkingDirectory; RemovedEnvironment = $RemovedEnvironment
        Environment = $Environment
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = New-MRSmokeProcessStartInfo @startArguments
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        [void] $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit([Math]::Max(1,[int][Math]::Floor($TimeoutSeconds * 1000)))) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "TIMEOUT: process tree exceeded the remaining $([Math]::Round($TimeoutSeconds,3))-second budget."
        }
        return [ordered]@{
            exitCode = $process.ExitCode
            stdout = $stdout.GetAwaiter().GetResult()
            stderr = $stderr.GetAwaiter().GetResult()
            seconds = [Math]::Round($watch.Elapsed.TotalSeconds,3)
        }
    } finally {
        $watch.Stop()
        $process.Dispose()
    }
}

function Expand-MRSmokeProfileArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $RunnerProfile,
        [Parameter(Mandatory)][string] $Worktree,
        [Parameter(Mandatory)][string] $OutputFile,
        [Parameter(Mandatory)][string] $Family,
        [Parameter(Mandatory)][string] $Prompt
    )
    $model = [string] $RunnerProfile.model
    $effort = [string] $RunnerProfile.reasoningEffort
    $arguments = @($RunnerProfile.arguments | ForEach-Object {
        ([string]$_).Replace('{model}',$model).Replace('{reasoningEffort}',$effort).Replace('{worktree}',$Worktree).Replace('{outputFile}',$OutputFile)
    })
    $jsonIndex = [Array]::IndexOf([object[]]$arguments,'-HarnessArgumentsJson')
    if ($jsonIndex -ge 0) {
        $harnessArguments = [Collections.Generic.List[string]]::new()
        foreach ($argument in @($arguments[$jsonIndex + 1] | ConvertFrom-Json)) {
            $harnessArguments.Add(([string]$argument).Replace('{model}',$model).Replace('{reasoningEffort}',$effort).Replace('{worktree}',$Worktree).Replace('{prompt}',$Prompt))
        }
        $promptIndex = $harnessArguments.IndexOf('--prompt')
        switch ($Family) {
            'Copilot' {
                if ($promptIndex -lt 0) { throw 'Copilot prompt argument missing.' }
                foreach ($permission in @('--trust-folder','--allow-tool=write','--allow-tool=shell')) {
                    $harnessArguments.Insert($promptIndex,$permission); $promptIndex++
                }
            }
            'Claude' {
                $promptIndex = $harnessArguments.Count - 1
                foreach ($permission in @('--allowedTools','Bash','Write','Edit','--')) {
                    $harnessArguments.Insert($promptIndex,$permission); $promptIndex++
                }
            }
            'OpenCode' {
                $agentIndex = $harnessArguments.IndexOf('--agent')
                if ($agentIndex -lt 0) { throw 'OpenCode agent argument missing.' }
                $harnessArguments.Insert($agentIndex,'--auto')
            }
        }
        $arguments[$jsonIndex + 1] = ConvertTo-Json -InputObject @($harnessArguments) -Compress
    } else {
        $arguments = @($arguments | ForEach-Object { ([string]$_).Replace('{prompt}',$Prompt) })
        if ($Family -eq 'Antigravity') {
            $printIndex = [Array]::IndexOf([object[]]$arguments,'--print')
            if ($printIndex -lt 1) { throw 'agy print argument missing.' }
            $arguments = @($arguments[0..($printIndex - 1)] + @('--settings','{"permissions":{"allow":["command(*)"]}}') + $arguments[$printIndex..($arguments.Count - 1)])
        }
    }
    return $arguments
}

function Test-MRSmokeRequired {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]] $ChangedPaths, [Parameter(Mandatory)][string[]] $TriggerPaths)
    foreach ($path in $ChangedPaths) {
        foreach ($pattern in $TriggerPaths) {
            if ($path -like $pattern) { return $true }
        }
    }
    return $false
}

function Get-MRSmokeFinalStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]] $Attempts)
    $passed = @($Attempts | Where-Object { [string]$_.status -ceq 'PASS' })
    if ($passed.Count -gt 0) { return $(if ([int]$passed[-1].attempt -eq 1) { 'PASS' } else { 'PASS_WITH_RETRY' }) }
    if (@($Attempts | Where-Object { [string]$_.status -ceq 'INFRA_ERROR' }).Count) { return 'INFRA_ERROR' }
    if (@($Attempts | Where-Object { [string]$_.status -ceq 'TIMEOUT' }).Count) { return 'TIMEOUT' }
    if (@($Attempts | Where-Object { [string]$_.status -ceq 'FAILED' }).Count) { return 'FAILED' }
    return 'BLOCKED'
}

function Write-MRSmokeJsonAtomic {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)] $Value)
    $directory = Split-Path -Parent $Path
    if ($PSCmdlet.ShouldProcess($Path,'Write smoke-test report')) {
        [void](New-Item -ItemType Directory -Path $directory -Force)
        $temporary = "$Path.tmp.$PID"
        try {
            [IO.File]::WriteAllText($temporary,($Value | ConvertTo-Json -Depth 50) + [Environment]::NewLine,[Text.UTF8Encoding]::new($false))
            [IO.File]::Move($temporary,$Path,$true)
        } finally {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Read-MRSmokeConfiguration,Merge-MRSmokeSelectionOverride,New-MRSmokeProcessStartInfo,Invoke-MRSmokeProcess,Expand-MRSmokeProfileArguments,Test-MRSmokeRequired,Get-MRSmokeFinalStatus,Write-MRSmokeJsonAtomic
