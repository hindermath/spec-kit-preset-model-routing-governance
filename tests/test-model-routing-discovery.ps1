#Requires -Version 7.0
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# The old default/name-regex mapping is intentionally removed. Its positive
# fixture is superseded by explicit suitability, while ambiguity stays blocked.
& (Join-Path $PSScriptRoot 'test-dynamic-model-routing.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
