<#
.SYNOPSIS
    DE: Gemeinsame normale Profil-Ausfuehrung. EN: Shared production profile execution.
.DESCRIPTION
    DE: Physische Pfade, JSON-sicherer Argumenttransport und sitzungsgebundene Rollenrechte.
    EN: Physical paths, JSON-safe argument transport and session-scoped role permissions.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-MRExecutionPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    $full = [IO.Path]::GetFullPath($Path)
    $current = [IO.Path]::GetPathRoot($full)
    foreach ($part in $full.Substring($current.Length).Split([char[]]@('/','\'),[StringSplitOptions]::RemoveEmptyEntries)) {
        $current = Join-Path $current $part
        $item = Get-Item -LiteralPath $current -Force
        if ($null -ne $item.LinkTarget) { $current = Resolve-MRExecutionPath $item.ResolveLinkTarget($true).FullName }
    }
    return $current
}

function Expand-MRExecutionArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Collections.IDictionary] $ExecutionProfile,
        [Parameter(Mandatory)][hashtable] $Values,
        [switch] $Preflight
    )
    $arguments = [Collections.Generic.List[string]]::new()
    $templates = @($ExecutionProfile.arguments)
    for ($index = 0; $index -lt $templates.Count; $index++) {
        $value = [string]$templates[$index]
        if ($index -gt 0 -and [string]$templates[$index - 1] -ceq '-HarnessArgumentsJson') {
            # Decode before substitution: a quoted or multiline prompt is data,
            # never raw JSON syntax. Re-encode only after all replacements.
            $inner = @($value | ConvertFrom-Json -NoEnumerate | ForEach-Object { $_ })
            $expanded = foreach ($item in $inner) {
                $text = [string]$item
                foreach ($entry in $Values.GetEnumerator()) { $text = $text.Replace("{$($entry.Key)}",[string]$entry.Value) }
                $text
            }
            $value = ConvertTo-Json -InputObject @($expanded) -Compress
        } else {
            foreach ($entry in $Values.GetEnumerator()) { $value = $value.Replace("{$($entry.Key)}",[string]$entry.Value) }
        }
        $arguments.Add($value)
    }
    if ($Preflight -or -not $ExecutionProfile.Contains('agentFamily')) { return $arguments.ToArray() }
    $family = [string]$ExecutionProfile.agentFamily
    $readOnly = [string]$ExecutionProfile.routingRole -ceq 'fast-mechanical'
    if ($family -ceq 'Antigravity') {
        $path = Resolve-MRExecutionPath ([string]$Values.worktree)
        $allow = @(if ($readOnly) { "read_file($path)" } else { 'command(*)';"write_file($path)" })
        $settings = @{permissions=@{allow=$allow}} | ConvertTo-Json -Depth 5 -Compress
        $index = $arguments.IndexOf('--print')
        if ($index -lt 0) { throw 'Antigravity print argument missing.' }
        $arguments.Insert($index,'--settings');$arguments.Insert($index + 1,$settings)
    } elseif ($family -cin @('Claude','Copilot','OpenCode') -and -not $readOnly) {
        $index = $arguments.IndexOf('-HarnessArgumentsJson')
        if ($index -lt 0) { throw 'Structured harness argument transport missing.' }
        $inner = [Collections.Generic.List[string]]::new()
        foreach ($value in @($arguments[$index + 1] | ConvertFrom-Json)) { $inner.Add([string]$value) }
        switch ($family) {
            Claude {
                $position = $inner.Count - 1
                foreach ($flag in @('--allowedTools','Bash','Write','Edit','--')) { $inner.Insert($position,$flag);$position++ }
            }
            Copilot {
                $position = $inner.IndexOf('--prompt')
                if ($position -lt 0) { throw 'Copilot prompt argument missing.' }
                foreach ($flag in @('--trust-folder','--allow-tool=write','--allow-tool=shell')) { $inner.Insert($position,$flag);$position++ }
            }
            OpenCode {
                $position = $inner.IndexOf('--agent')
                if ($position -lt 0) { throw 'OpenCode agent argument missing.' }
                $inner.Insert($position,'--auto')
            }
        }
        $arguments[$index + 1] = ConvertTo-Json -InputObject @($inner) -Compress
    }
    return $arguments.ToArray()
}

Export-ModuleMember -Function Resolve-MRExecutionPath,Expand-MRExecutionArguments
