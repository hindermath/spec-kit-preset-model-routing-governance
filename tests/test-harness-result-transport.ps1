Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$adapter = Join-Path $root 'scripts/adapters/invoke-harness-with-result.ps1'
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('model-routing-result-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temporary)
try {
    $fixture = Join-Path $temporary 'fixture.ps1'
    @'
param([ValidateSet('valid','invalid','failed','copilot')][string]$Mode)
if($Mode -eq 'failed'){exit 23}
if($Mode -eq 'invalid'){Write-Output 'not-json';exit 0}
if($Mode -eq 'copilot'){
    [ordered]@{type='session.info';data=@{message='ignored'}}|ConvertTo-Json -Compress
    [ordered]@{type='assistant.message';data=@{content='intermediate progress'}}|ConvertTo-Json -Compress
    [ordered]@{type='assistant.message';data=@{content='{"phaseId":"fixture","status":"Completed","tasks":[],"gates":[]}'}}|ConvertTo-Json -Compress
    [ordered]@{type='result';data=@{exitCode=0}}|ConvertTo-Json -Compress
    exit 0
}
[ordered]@{phaseId='fixture';status='Completed';tasks=@();gates=@()}|ConvertTo-Json -Compress
'@ | Set-Content -LiteralPath $fixture -Encoding utf8NoBOM
    $result = Join-Path $temporary 'result.json'
    $plainArguments = @('-NoProfile','-File',$fixture,'-Mode','valid') | ConvertTo-Json -Compress
    $output = @(& $adapter -OutputFile $result -Executable pwsh -HarnessArgumentsJson $plainArguments)
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $result) -or ($output -join "`n") -cne (Get-Content $result -Raw).Trim()) { throw 'Valid structured stdout was not persisted and preserved.' }
    Remove-Item $result
    $copilotArguments = @('-NoProfile','-File',$fixture,'-Mode','copilot') | ConvertTo-Json -Compress
    $copilotOutput = @(& $adapter -OutputFile $result -Executable pwsh -OutputProtocol CopilotJsonl -HarnessArgumentsJson $copilotArguments)
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $result) -or ($copilotOutput -join "`n") -cne (Get-Content $result -Raw).Trim()) { throw 'Copilot JSONL final assistant message was not persisted.' }
    Remove-Item $result
    foreach($mode in @('invalid','failed')) {
        $rejected = $false
        $arguments = @('-NoProfile','-File',$fixture,'-Mode',$mode) | ConvertTo-Json -Compress
        try { & $adapter -OutputFile $result -Executable pwsh -HarnessArgumentsJson $arguments 2>$null | Out-Null } catch { $rejected = $true }
        if($mode -eq 'invalid' -and -not $rejected){throw 'Invalid structured output did not fail closed.'}
        if(Test-Path $result){throw "$mode output created a result file."}
    }
    Write-Output 'PASS: harness result transport persists only successful JSON objects.'
} finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force
}
