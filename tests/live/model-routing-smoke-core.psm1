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
    $cancellation = [Threading.CancellationTokenSource]::new()
    try {
        [void] $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync($cancellation.Token)
        $stderr = $process.StandardError.ReadToEndAsync($cancellation.Token)
        if (-not $process.WaitForExit([Math]::Max(1,[int][Math]::Floor($TimeoutSeconds * 1000)))) {
            $process.Kill($true)
            [void]$process.WaitForExit(2000)
            throw "TIMEOUT: process tree exceeded the remaining $([Math]::Round($TimeoutSeconds,3))-second budget."
        }
        # Descendants can retain inherited pipes after their parent exits. Drain
        # only within the original deadline, never via an unbounded GetResult.
        $remainingMilliseconds = [Math]::Max(1,[int](($TimeoutSeconds - $watch.Elapsed.TotalSeconds) * 1000))
        $drain = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($stdout,$stderr))
        if (-not $drain.Wait($remainingMilliseconds)) {
            throw 'TIMEOUT: inherited output pipes remained open after child exit.'
        }
        return [ordered]@{
            exitCode = $process.ExitCode
            stdout = $stdout.GetAwaiter().GetResult()
            stderr = $stderr.GetAwaiter().GetResult()
            seconds = [Math]::Round($watch.Elapsed.TotalSeconds,3)
        }
    } finally {
        $watch.Stop()
        $cancellation.Cancel()
        $process.Dispose()
        $cancellation.Dispose()
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

function ConvertTo-MRSmokeDiagnosticText {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string] $Text = '',
        [int] $MaxBytes = 16384,
        [string[]] $RedactValues = @(),
        [hashtable] $PathReplacements = @{}
    )
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $safe = $Text.Replace("`r`n","`n").Replace("`r","`n")
    foreach ($entry in @($PathReplacements.GetEnumerator() | Sort-Object { ([string]$_.Key).Length } -Descending)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$entry.Key)) { $safe = $safe.Replace([string]$entry.Key,[string]$entry.Value) }
    }
    foreach ($value in @($RedactValues | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_.Length -ge 4 } | Sort-Object Length -Descending -Unique)) {
        $safe = $safe.Replace($value,'<redacted>')
    }
    $safe = [regex]::Replace($safe,'(?i)\b(Bearer|Basic)\s+[A-Za-z0-9+/=._~-]+','$1 <redacted>')
    $safe = [regex]::Replace($safe,'(?i)\b(api[_-]?key|token|password|authorization)\b(\s*[:=]\s*)([^\s,;]+)','$1$2<redacted>')
    $safe = [regex]::Replace($safe,'\bsk-[A-Za-z0-9_-]{8,}\b','<redacted>')
    $safe = [regex]::Replace($safe,'\bgh[pousr]_[A-Za-z0-9]{8,}\b','<redacted>')
    $bytes = [Text.Encoding]::UTF8.GetBytes($safe)
    if ($bytes.Length -le $MaxBytes) { return $safe }
    $prefix = [Text.Encoding]::UTF8.GetString($bytes,0,$MaxBytes)
    return $prefix + "`n<truncated:originalBytes=$($bytes.Length)>"
}

function ConvertTo-MRSmokeProcessDiagnostic {
    [CmdletBinding()]
    param(
        $ProcessResult,
        [string[]] $RedactValues = @(),
        [hashtable] $PathReplacements = @{}
    )
    if ($null -eq $ProcessResult) { return $null }
    return [ordered]@{
        exitCode = $ProcessResult.exitCode
        seconds = $ProcessResult.seconds
        stdout = ConvertTo-MRSmokeDiagnosticText -Text ([string]$ProcessResult.stdout) -RedactValues $RedactValues -PathReplacements $PathReplacements
        stderr = ConvertTo-MRSmokeDiagnosticText -Text ([string]$ProcessResult.stderr) -RedactValues $RedactValues -PathReplacements $PathReplacements
    }
}

function Get-MRSmokeAgentResultDiagnostic {
    [CmdletBinding()]
    param([string] $OutputFile = '', [AllowEmptyString()][string] $StandardOutput = '')
    $candidate = if ($OutputFile -and (Test-Path -LiteralPath $OutputFile -PathType Leaf)) {
        Get-Content -LiteralPath $OutputFile -Raw
    } else { $StandardOutput }
    if ([string]::IsNullOrWhiteSpace($candidate)) { return $null }
    try { $value = $candidate | ConvertFrom-Json -AsHashtable -Depth 20 }
    catch { return $null }
    if ($value -isnot [Collections.IDictionary]) { return $null }
    $result = [ordered]@{}
    foreach ($key in @('created','executed','verified')) {
        if ($value.Contains($key) -and $value[$key] -is [bool]) { $result[$key] = [bool]$value[$key] }
    }
    if ($result.Count -eq 0) { return $null }
    return $result
}

function Get-MRSmokeProjectDiagnostics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Worktree,
        [string[]] $RedactValues = @(),
        [hashtable] $PathReplacements = @{}
    )
    if (-not (Test-Path -LiteralPath $Worktree -PathType Container)) { return [ordered]@{files=@();truncated=$false} }
    $entries = [Collections.Generic.List[object]]::new()
    $allFiles = @(Get-ChildItem -LiteralPath $Worktree -Recurse -File -Force -ErrorAction SilentlyContinue | Sort-Object FullName)
    $truncated = $false
    foreach ($file in $allFiles) {
        $relative = [IO.Path]::GetRelativePath($Worktree,$file.FullName).Replace('\','/')
        if ($relative -match '(^|/)\.git(/|$)' -or $relative -match '(^|/)\.specify(/|$)' -or
            $relative -match '(^|/)\.dotnet(/|$)' -or
            $relative -match '(^|/)obj(/|$)') { continue }
        $inBin = $relative -match '(^|/)bin(/|$)'
        $selectedRuntimeMetadata = $relative -match '\.(runtimeconfig|deps)\.json$'
        if ($inBin -and -not $selectedRuntimeMetadata) { continue }
        if ($entries.Count -ge 200) { $truncated = $true;break }
        $entry = [ordered]@{path=$relative;size=[long]$file.Length;sha256=$null}
        try { $entry.sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
        catch { $entry.hashUnavailable = $true }
        if ($relative -match '\.csproj$' -or [IO.Path]::GetFileName($relative) -ceq 'Program.cs' -or $selectedRuntimeMetadata) {
            try {
                $raw = [IO.File]::ReadAllText($file.FullName)
                $entry.content = ConvertTo-MRSmokeDiagnosticText -Text $raw -MaxBytes 32768 -RedactValues $RedactValues -PathReplacements $PathReplacements
            } catch { $entry.contentUnavailable = $true }
        }
        $entries.Add($entry)
    }
    return [ordered]@{files=$entries.ToArray();truncated=$truncated}
}

function Limit-MRSmokeAttemptDiagnostics {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Collections.IDictionary] $Diagnostics, [int] $MaxBytes = 131072)
    $serialized = $Diagnostics | ConvertTo-Json -Depth 50 -Compress
    if ([Text.Encoding]::UTF8.GetByteCount($serialized) -le $MaxBytes) { return $Diagnostics }
    if ($Diagnostics.project -is [Collections.IDictionary]) {
        foreach ($file in @($Diagnostics.project.files | Sort-Object size -Descending)) {
            if ($file -is [Collections.IDictionary] -and $file.Contains('content')) {
                $file.Remove('content');$file.contentOmittedByAttemptLimit=$true
                $serialized = $Diagnostics | ConvertTo-Json -Depth 50 -Compress
                if ([Text.Encoding]::UTF8.GetByteCount($serialized) -le $MaxBytes) { return $Diagnostics }
            }
        }
        if ($Diagnostics.project.files.Count -gt 50) {
            $Diagnostics.project.files = @($Diagnostics.project.files | Select-Object -First 50)
            $Diagnostics.project.truncated = $true
        }
    }
    $serialized = $Diagnostics | ConvertTo-Json -Depth 50 -Compress
    if ([Text.Encoding]::UTF8.GetByteCount($serialized) -gt $MaxBytes) {
        foreach ($processName in @('agent','build','run','preflight')) {
            $process = $Diagnostics.processes[$processName]
            if ($process -is [Collections.IDictionary]) {
                $process.stdout = ConvertTo-MRSmokeDiagnosticText -Text ([string]$process.stdout) -MaxBytes 4096
                $process.stderr = ConvertTo-MRSmokeDiagnosticText -Text ([string]$process.stderr) -MaxBytes 4096
            }
        }
        $Diagnostics.attemptLimitApplied = $true
    }
    return $Diagnostics
}

function Read-MRSmokeReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    $report = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 50
    if ([string]$report.schemaVersion -notin @('1.0','1.1') -or [string]$report.testId -cne 'model-routing-live-smoke') {
        throw 'Smoke report schema or test ID is unsupported.'
    }
    return $report
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

Export-ModuleMember -Function Read-MRSmokeConfiguration,Merge-MRSmokeSelectionOverride,New-MRSmokeProcessStartInfo,Invoke-MRSmokeProcess,Expand-MRSmokeProfileArguments,ConvertTo-MRSmokeDiagnosticText,ConvertTo-MRSmokeProcessDiagnostic,Get-MRSmokeAgentResultDiagnostic,Get-MRSmokeProjectDiagnostics,Limit-MRSmokeAttemptDiagnostics,Read-MRSmokeReport,Test-MRSmokeRequired,Get-MRSmokeFinalStatus,Write-MRSmokeJsonAtomic
