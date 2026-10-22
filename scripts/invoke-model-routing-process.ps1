#Requires -Version 7.0
<#
.SYNOPSIS
    Argumentvektor portabel starten / Launch a portable argument vector.
.DESCRIPTION
    DE: Interner Child des begrenzten Runners. Kein Eval und keine Shell-
    Verkettung. PowerShell loest auch Windows-npm-Shims korrekt auf.
    EN: Internal bounded-runner child; no eval or shell concatenation.
    PowerShell also resolves Windows npm shims without cmd.exe interpolation.
.PARAMETER Executable
    Bereits ausgewaehlter Harness / Already selected harness executable.
.PARAMETER ArgumentsBase64
    UTF-8-JSON-Argumentarray / UTF-8 JSON argument array encoded as Base64.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Executable,[Parameter(Mandatory)][string]$ArgumentsBase64)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Preserve one-element arrays such as ["--version"] instead of unwrapping
# them to a scalar and rejecting an otherwise safe metadata command.
$arguments=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ArgumentsBase64)) | ConvertFrom-Json -NoEnumerate
if ($arguments -isnot [array]) { throw 'Expected an argument array.' }
& $Executable @arguments
exit $(if ($null -eq $LASTEXITCODE) {0} else {$LASTEXITCODE})
