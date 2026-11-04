#Requires -Version 7.3
<#
.SYNOPSIS
    DE: Prueft die normale Ausfuehrungspolicy offline. EN: Tests the production execution policy offline.
.DESCRIPTION
    DE: Prueft Rollenrechte, Preflight, JSON-Transport und physische Pfade ohne Modelle.
    EN: Checks role permissions, preflight, JSON transport and physical paths without models.
.EXAMPLE
    pwsh -NoProfile -File tests/test-execution-policy.ps1
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/execution-policy.psm1') -Force
$temporary = Join-Path ([IO.Path]::GetTempPath()) "execution-policy-$([guid]::NewGuid().ToString('N'))"
[void](New-Item -ItemType Directory -Path $temporary)
try {
    $values = @{worktree=$temporary;model='test-model';reasoningEffort='high';prompt="quoted `"text`"`nnext line";outputFile=(Join-Path $temporary 'result.json')}
    foreach ($family in @('Claude','Copilot','OpenCode')) {
        $inner = switch ($family) {
            Claude { @('--permission-mode','acceptEdits','{prompt}') }
            Copilot { @('--prompt','{prompt}') }
            OpenCode { @('run','--agent','build','{prompt}') }
        }
        $executionProfile = @{agentFamily=$family;routingRole='long-running-implementation';arguments=@('-HarnessArgumentsJson',(ConvertTo-Json -InputObject $inner -Compress))}
        $before = $executionProfile | ConvertTo-Json -Depth 10 -Compress
        $expanded = @(Expand-MRExecutionArguments $executionProfile $values)
        $decoded = @($expanded[1] | ConvertFrom-Json)
        if ($values.prompt -cnotin $decoded) { throw "$family lost multiline quoted prompt." }
        $permission = switch ($family) { Claude {'--allowedTools'} Copilot {'--allow-tool=write'} OpenCode {'--auto'} }
        if ($permission -cnotin $decoded) { throw "$family missing implementation permissions." }
        if (($executionProfile | ConvertTo-Json -Depth 10 -Compress) -cne $before) { throw 'Persistent profile was mutated.' }
        $executionProfile.routingRole = 'fast-mechanical'
        $readonly = @(Expand-MRExecutionArguments $executionProfile $values)
        if ($permission -cin @($readonly[1] | ConvertFrom-Json)) { throw "$family escalated read-only permissions." }
        $preflight = @(Expand-MRExecutionArguments $executionProfile $values -Preflight)
        if ($permission -cin @($preflight[1] | ConvertFrom-Json)) { throw "$family escalated preflight." }
    }
    foreach ($role in @('fast-mechanical','long-running-implementation')) {
        $executionProfile = @{agentFamily='Antigravity';routingRole=$role;arguments=@('--print','{prompt}')}
        $expanded = @(Expand-MRExecutionArguments $executionProfile $values)
        $settings = ($expanded[1] | ConvertFrom-Json).permissions.allow
        $path = Resolve-MRExecutionPath $temporary
        if ($role -ceq 'fast-mechanical') {
            if ($settings.Count -ne 1 -or $settings[0] -cne "read_file($path)") { throw 'Read-only agy grants too much.' }
        } elseif ($settings.Count -ne 2 -or "write_file($path)" -cnotin $settings) { throw 'agy write scope mismatch.' }
        $preflight = @(Expand-MRExecutionArguments $executionProfile $values -Preflight)
        if ('--settings' -cin $preflight) { throw 'agy preflight escalated.' }
    }
    $codex = @{agentFamily='Codex';routingRole='long-running-implementation';arguments=@('exec','--cd','{worktree}','{prompt}')}
    $expanded = @(Expand-MRExecutionArguments $codex $values)
    if ($expanded.Count -ne 4 -or $expanded[-1] -cne $values.prompt) { throw 'Codex argument semantics changed.' }
    'PASS: production execution policy, role boundaries, preflight and JSON transport; offline.'
} finally { Remove-Item -LiteralPath $temporary -Recurse -Force }
