#Requires -Version 7.0
<#
.SYNOPSIS
    Alle Matrix-Commands abdecken / Cover all matrix commands.
.DESCRIPTION
    DE: Read-only Quellenpruefung aller 14 kanonischen Preset-Repositories.
    EN: Read-only source audit of all fourteen canonical preset repositories.
.PARAMETER MatrixPath
    Zentrale 14er-Matrix / Central fourteen-preset matrix.
.PARAMETER PresetProjectsRoot
    Gemeinsames Quellenverzeichnis / Parent directory of canonical sources.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$MatrixPath,[Parameter(Mandatory)][string]$PresetProjectsRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/dynamic-model-routing.psm1') -Force
$matrix=Read-MRDocument $MatrixPath
if (@($matrix.presets).Count -ne 14) { throw 'Expected the complete explicit fourteen-preset matrix.' }
$total=0
foreach ($preset in $matrix.presets) {
    $root=Join-Path $PresetProjectsRoot ('spec-kit-preset-'+$preset.id)
    $manifest=Get-Content -LiteralPath (Join-Path $root 'preset.yml') -Raw
    $catalog=Read-MRDocument (Join-Path $root 'model-routing.json')
    if ($catalog.presetId -cne $preset.id) { throw "Wrong catalog identity: $($preset.id)" }
    $commands=@([regex]::Matches($manifest,'\bname:\s*"?(speckit\.[A-Za-z0-9_.-]+)"?') | ForEach-Object {$_.Groups[1].Value})
    if ($commands.Count -eq 0) { throw "No command declarations parsed: $($preset.id)" }
    foreach ($command in $commands) {
        if (-not $catalog.commands.ContainsKey($command)) { throw "Missing routing contract: $($preset.id)/$command" }
    }
    $total+=$commands.Count
    Write-Output "PASS: $($preset.id), $($commands.Count) commands covered"
}
$effective=Get-MRCatalog $PresetProjectsRoot
if ($effective.commands['speckit.plan'] -ne 'frontier-reasoning') { throw 'Strongest role composition failed.' }
Write-Output "RESULT: 14 presets, $total declared commands covered; strongest-role composition valid."
