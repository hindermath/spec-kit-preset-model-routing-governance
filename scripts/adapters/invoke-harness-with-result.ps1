#Requires -Version 7
<#
.SYNOPSIS
Runs a harness and persists its structured standard output atomically.
.DESCRIPTION
The autonomous runner requires a result file, while Claude, Copilot and
OpenCode return their final answer on standard output. This adapter captures
successful JSON-only output, validates that it is a JSON object, writes it to
the exact runner-owned path, and also returns it for the ordinary phase log.
No result is written when the harness fails or emits non-JSON output.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $OutputFile,
    [Parameter(Mandatory)][string] $Executable,
    [Parameter(ValueFromRemainingArguments)][string[]] $HarnessArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$output = @(& $Executable @HarnessArguments)
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) { exit $exitCode }

$text = $output -join "`n"
if ([string]::IsNullOrWhiteSpace($text)) {
    throw 'Harness returned no structured standard output.'
}
$parsed = $text | ConvertFrom-Json -AsHashtable -Depth 100
if ($parsed -isnot [Collections.IDictionary]) {
    throw 'Harness standard output must be one JSON object.'
}

$target = [IO.Path]::GetFullPath($OutputFile)
$directory = Split-Path -Parent $target
[void](New-Item -ItemType Directory -Path $directory -Force)
$temporary = Join-Path $directory ('.' + [IO.Path]::GetFileName($target) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    [IO.File]::WriteAllText($temporary, $text + "`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temporary, $target, $true)
} finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
}
$output
