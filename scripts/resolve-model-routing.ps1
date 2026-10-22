#Requires -Version 7.0
<#
.SYNOPSIS
    Lokales Routing pruefen / Inspect local routing.
.DESCRIPTION
    DE: Status und Preview sind read-only ohne Inferenz. Discovery ist kein
    Eignungsnachweis. Refresh schreibt nur mit expliziter lokaler Freigabe.
    EN: Status and Preview never infer or write. Discovery is not suitability
    evidence. Refresh requires explicit approval; it grants no run authority.
.PARAMETER Action
    Status, Preview oder expliziter Refresh / Status, Preview or explicit Refresh.
.PARAMETER Harness
    Expliziter Harness; Auto verlangt Klaerung / Explicit harness; Auto needs clarification.
.PARAMETER ConfigPath
    Lokale, nicht versionierte Konfiguration / Local untracked configuration.
.PARAMETER RoutingRoot
    Installierte Routing-Vertraege / Installed routing contracts.
.PARAMETER RequirementsPath
    Explizite Phasenanforderungen / Explicit phase requirements JSON.
.PARAMETER ProjectRoot
    Gebundene Projektwurzel / Bound project root.
.PARAMETER InputConfig
    Genehmigter Migrationsentwurf / Approved migration draft for Refresh.
.PARAMETER ApproveLocalRefresh
    Explizite Schreibfreigabe, keine Laufberechtigung / Explicit write approval only.
.PARAMETER Discover
    Modellmetadaten lesen ohne Inferenz / Read model metadata without inference.
.PARAMETER OutputFormat
    Json oder barrierearmer Text / Json or accessible text.
.EXAMPLE
    ./resolve-model-routing.ps1 -Action Preview -Harness Codex -RequirementsPath phase.json -RoutingRoot .specify/presets
.EXAMPLE
    ./resolve-model-routing.ps1 -Action Refresh -Harness Claude -InputConfig draft.json -RequirementsPath phase.json -RoutingRoot .specify/presets -ApproveLocalRefresh -WhatIf
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory)][ValidateSet('Status','Preview','Refresh')][string] $Action,
    [ValidateSet('Auto','Codex','Claude','Copilot','Antigravity','OpenCode')][string] $Harness='Auto',
    [string] $ConfigPath='',
    [string] $RoutingRoot='',
    [string] $RequirementsPath='',
    [string] $ProjectRoot=(Get-Location).Path,
    [string] $InputConfig='',
    [switch] $ApproveLocalRefresh,
    [switch] $Discover,
    [ValidateSet('Text','Json')][string] $OutputFormat='Text'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'dynamic-model-routing.psm1') -Force

function Invoke-MRCodexDiscovery {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'codex'
    foreach ($argument in @('app-server','--listen','stdio://')) { $start.ArgumentList.Add($argument) }
    $start.UseShellExecute=$false; $start.RedirectStandardInput=$true
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$start; $started=$false
    try {
        $started=$process.Start()
        if (-not $started) { throw 'Codex discovery could not start.' }
        $stderrTask=$process.StandardError.ReadToEndAsync()
        $deadline=[DateTime]::UtcNow.AddSeconds(20)
        $request=@{id=1;method='initialize';params=@{clientInfo=@{name='model-routing-governance';version='development'};capabilities=@{experimentalApi=$true}}}
        $process.StandardInput.WriteLine(($request | ConvertTo-Json -Depth 10 -Compress)); $process.StandardInput.Flush()
        $requestId=1; $models=[Collections.Generic.List[object]]::new(); $pages=0
        $cursors=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        while ($true) {
            $remaining=[int]($deadline-[DateTime]::UtcNow).TotalMilliseconds
            if ($remaining -le 0) { throw 'Codex discovery timeout.' }
            $read=$process.StandardOutput.ReadLineAsync()
            if (-not $read.Wait($remaining)) { throw 'Codex discovery timeout.' }
            $line=$read.GetAwaiter().GetResult()
            if ($null -eq $line) { throw 'Codex ended before discovery completed.' }
            $message=$line | ConvertFrom-Json -AsHashtable
            if (-not $message.ContainsKey('id') -or [int]$message.id -ne $requestId) { continue }
            if ($message.ContainsKey('error')) { throw 'Codex rejected discovery.' }
            if ($requestId -eq 1) {
                $process.StandardInput.WriteLine('{"method":"initialized","params":{}}')
                $next=$null
            } else {
                foreach ($item in @($message.result.data)) { if (-not [bool]$item.hidden) { $models.Add($item) } }
                $next=$message.result.nextCursor
                if ([string]::IsNullOrWhiteSpace([string]$next)) { break }
                if (-not $cursors.Add([string]$next)) { throw 'Repeated Codex pagination cursor.' }
            }
            $pages++; if ($pages -gt 100) { throw 'Codex discovery pagination limit exceeded.' }
            $requestId++
            $parameters=@{limit=100;includeHidden=$false}; if ($null -ne $next) { $parameters.cursor=$next }
            $process.StandardInput.WriteLine((@{id=$requestId;method='model/list';params=$parameters} | ConvertTo-Json -Compress)); $process.StandardInput.Flush()
        }
        return $models.ToArray()
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true); [void]$process.WaitForExit(2000) }
        if ($started) { [void]$stderrTask.GetAwaiter().GetResult() }
        $process.Dispose()
    }
}

function Get-MRDiscovery {
    param([string] $Family, [hashtable] $LocalConfig)
    switch ($Family) {
        Codex {
            $models=@(Invoke-MRCodexDiscovery | ForEach-Object {
                @{id=[string]$_.model;efforts=@($_.supportedReasoningEfforts | ForEach-Object {[string]$_.reasoningEffort})}
            })
            return @{mode='Enumerate';models=$models;access='NotProbed'}
        }
        Antigravity {
            $lines=@(& agy models 2>&1)
            if ($LASTEXITCODE -ne 0) { throw 'agy models failed.' }
            $models=@($lines | ForEach-Object {
                $parts=([string]$_) -split "`t",2
                if ($parts.Count -eq 2 -and $parts[0] -match '^[A-Za-z0-9][A-Za-z0-9._:/-]+$') {
                    @{id=$parts[0];efforts=@();capabilityStatus='Unverified'}
                }
            })
            return @{mode='EnumerateNames';models=$models;access='NotProbed'}
        }
        default {
            if (-not $LocalConfig.ContainsKey('inventory')) { return @{mode='ConfiguredOnly';models=@();access='NotProbed'} }
            return @{mode='ConfiguredCandidates';models=@($LocalConfig.inventory.models);access='NotProbed'}
        }
    }
}

$result=@{schemaVersion='1.0';status='Blocked';exitCode=3;reason='';nextAction='Correct routing input and repeat Status/Preview.'}
try {
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $legacy=Join-Path $HOME '.home-baseline/spec-kit/runner-profiles.local.json'
        if (Test-Path -LiteralPath $legacy -PathType Leaf) { $ConfigPath=$legacy }
        elseif ($IsWindows -and $env:APPDATA) { $ConfigPath=Join-Path $env:APPDATA 'spec-kit/model-routing-profiles.json' }
        else {
            $base=if ($env:XDG_CONFIG_HOME) {$env:XDG_CONFIG_HOME} else {Join-Path $HOME '.config'}
            $ConfigPath=Join-Path $base 'spec-kit/model-routing-profiles.json'
        }
    }
    $config=if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {Read-MRDocument $ConfigPath} else {@{}}
    if ($Harness -eq 'Auto') {
        $result.status='NeedsClarification'; $result.exitCode=4; $result.reason='Select one explicit harness; Auto grants no provider-switch authority.'
    } elseif ($Harness -eq 'OpenCode' -and $config.Count -eq 0 -and $Action -ne 'Refresh' -and -not $Discover) {
        $result.status='NotConfigured'; $result.exitCode=5; $result.reason='Optional OpenCode has no explicitly configured project/provider candidates.'
    } else {
        $executable=@{Codex='codex';Claude='claude';Copilot='copilot';Antigravity='agy';OpenCode='opencode'}[$Harness]
        $versionLines=@(& $executable --version 2>&1)
        if ($LASTEXITCODE -ne 0 -or $versionLines.Count -eq 0) { throw 'Harness version unavailable.' }
        $version=[string]$versionLines[0]
        if ($Action -eq 'Refresh') {
            if (-not $ApproveLocalRefresh -or [string]::IsNullOrWhiteSpace($InputConfig)) { throw 'Refresh requires -ApproveLocalRefresh and an explicit -InputConfig; no implicit migration.' }
            $config=Read-MRDocument $InputConfig
        }
        if ($Discover) {
            if ($Action -eq 'Refresh') { throw 'Discovery and persistent Refresh must be separate reviewed operations.' }
            $result=@{schemaVersion='1.0';status='NeedsClarification';exitCode=4;harness=$Harness;harnessVersion=$version;inventory=(Get-MRDiscovery $Harness $config);reason='Discovery is not suitability or access proof.';nextAction='Review local candidate evidence and use Preview.'}
        } elseif ($config.Count -eq 0 -or [string]$config.schemaVersion -ne '3.0') {
            $result.status=if ($config.Count -gt 0) {'RefreshRequired'} elseif ($Harness -eq 'OpenCode') {'NotConfigured'} else {'NeedsClarification'}
            $result.exitCode=@{RefreshRequired=2;NotConfigured=5;NeedsClarification=4}[$result.status]
            $result.reason='No schema-3 policy; old profiles remain untouched and require explicit migration.'
        } elseif ([string]::IsNullOrWhiteSpace($RequirementsPath)) {
            $result.status='NeedsClarification'; $result.exitCode=4; $result.reason='Provide explicit phase requirements; no implied difficulty classification.'
        } else {
            if ([string]::IsNullOrWhiteSpace($RoutingRoot)) { $RoutingRoot=Join-Path $ProjectRoot '.specify/presets' }
            $catalog=Get-MRCatalog $RoutingRoot
            $requirements=Read-MRDocument $RequirementsPath
            $result=Resolve-MRSelection -Config $config -Requirements $requirements -Catalog $catalog -Harness $Harness -HarnessVersion $version -ProjectRoot $ProjectRoot
            if ($Action -eq 'Refresh' -and $result.exitCode -eq 0 -and $PSCmdlet.ShouldProcess($ConfigPath,'Persist explicitly approved local schema-3 routing policy')) {
                $parent=Split-Path -Parent ([IO.Path]::GetFullPath($ConfigPath)); [void](New-Item -ItemType Directory -Path $parent -Force)
                $temporary=Join-Path $parent ([IO.Path]::GetRandomFileName())
                try { $config | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $temporary -Encoding utf8NoBOM; Move-Item -LiteralPath $temporary -Destination $ConfigPath -Force }
                finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
            }
        }
    }
} catch { $result.status='Blocked'; $result.exitCode=3; $result.reason=$_.Exception.Message }
if ($OutputFormat -eq 'Json') { $result | ConvertTo-Json -Depth 50 }
else { Write-Output "Model routing: $($result.status)"; Write-Output "Reason / Grund: $($result.reason)"; Write-Output "Next action / Naechste Aktion: $($result.nextAction)" }
exit [int]$result.exitCode
