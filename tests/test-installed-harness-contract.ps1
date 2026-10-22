#Requires -Version 7.0
<#
.SYNOPSIS
    Installierte CLI-Vertraege ohne Inferenz pruefen / Check installed CLIs without inference.
.DESCRIPTION
    DE: Fuehrt ausschliesslich --version und --help aus. Prueft dokumentierte
    Schalter, nicht Modellzugang, Berechtigungswirkung oder native Receipts.
    Fehlende CLI oder Schalter bleiben Blocked. Keine Installation/Anmeldung.
    EN: Runs only --version and --help. Checks documented switches, not model
    access, effective permissions or native receipts. No install or sign-in.
.PARAMETER TimeoutSeconds
    Frist je Metadatenprozess / Deadline per metadata process.
.EXAMPLE
    pwsh -NoProfile -File tests/test-installed-harness-contract.ps1
#>
[CmdletBinding()]
param([ValidateRange(1,120)][int]$TimeoutSeconds=30)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/dynamic-model-routing.psm1') -Force
$contracts=@(
    @{family='Codex';executable='codex';help=@('exec','--help');tokens=@('--model','--config','--ephemeral','--json','--sandbox','read-only','--output-last-message')},
    @{family='Claude';executable='claude';help=@('--help');tokens=@('--model','--effort','--output-format','stream-json','--permission-mode','manual','--permission-prompts','none','--tools')},
    @{family='Copilot';executable='copilot';help=@('--help');tokens=@('--model','--reasoning-effort','--output-format','--available-tools')},
    @{family='Antigravity';executable='agy';help=@('--help');tokens=@('--model','--effort','--output-format','--mode','plan','accept-edits','--print-timeout')},
    @{family='OpenCode';executable='opencode';help=@('run','--help');tokens=@('--standalone','--model','provider/model#variant','--agent','--format','json')}
)
$results=@(foreach($contract in $contracts) {
    try {
        # The literal allowlisted argument vectors cannot initiate a model turn.
        $version=Invoke-MRBoundedProcess @{executable=$contract.executable;arguments=@('--version')} @{} $PSScriptRoot -TimeoutSeconds $TimeoutSeconds
        $help=Invoke-MRBoundedProcess @{executable=$contract.executable;arguments=$contract.help} @{} $PSScriptRoot -TimeoutSeconds $TimeoutSeconds
        $after=Invoke-MRBoundedProcess @{executable=$contract.executable;arguments=@('--version')} @{} $PSScriptRoot -TimeoutSeconds $TimeoutSeconds
        if($version.exitCode -ne 0 -or $help.exitCode -ne 0 -or $after.exitCode -ne 0) {throw 'Metadata command failed or timed out.'}
        if(($version.output -join "`n") -cne ($after.output -join "`n")) {throw 'Harness version changed during CLI metadata audit.'}
        $helpText=($help.output -join "`n")+"`n"+$help.diagnostics
        $missing=@($contract.tokens | Where-Object {-not $helpText.Contains($_)})
        if($missing.Count -gt 0) {throw ('Missing documented switches: '+($missing -join ', '))}
        @{harness=$contract.family;cliVersion=(@($version.output | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})[0]).Trim();helpSha256=(Get-MRSha256 $helpText);status='CliSurfaceVerified';nativeConformance='NotVerified';access='NotProbed'}
    } catch {
        @{harness=$contract.family;status='Blocked';reason=$_.Exception.Message;nativeConformance='NotVerified';access='NotProbed'}
    }
})
@{schemaVersion='1.0';observedAt=[DateTimeOffset]::UtcNow.ToString('o');inferenceCalls=0;configurationWrites=0;results=$results} | ConvertTo-Json -Depth 8
if(@($results | Where-Object {$_.status -eq 'Blocked'}).Count -gt 0) {exit 3}
exit 0
