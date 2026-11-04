Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-MRValidationPair {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $RunStage)
    $stages = [Collections.Generic.List[object]]::new()
    foreach ($mode in @('smoke','production-phase-runner')) {
        try {
            $result = & $RunStage $mode
            if ($result -isnot [Collections.IDictionary]) { throw 'Stage returned no structured result.' }
            $stages.Add($result)
        } catch {
            $stages.Add([ordered]@{mode=$mode;finalStatus='INFRA_ERROR';error=$_.Exception.Message})
        }
    }
    $statuses = @($stages | ForEach-Object { [string]$_.finalStatus })
    $status = if (@($statuses | Where-Object { $_ -notin @('PASS','PASS_WITH_RETRY') }).Count) { 'FAILED' }
        elseif ($statuses -contains 'PASS_WITH_RETRY') { 'PASS_WITH_RETRY' } else { 'PASS' }
    return [ordered]@{finalStatus=$status;stages=$stages.ToArray()}
}

Export-ModuleMember -Function Invoke-MRValidationPair
