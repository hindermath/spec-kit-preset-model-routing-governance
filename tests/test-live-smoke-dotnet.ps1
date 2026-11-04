#Requires -Version 7.3
<#
.SYNOPSIS
    DE: Prueft physische Smoke-Test-Pfade ohne Modelle. EN: Checks physical smoke paths without models.
.DESCRIPTION
    DE: Baut und startet eine paketfreie .NET-10-App ueber den echten Kindprozess-
    Transport. Prueft Runtime-Dateien nach zwei Builds und entfernt alle Testdaten.
    EN: Builds and runs a package-free .NET 10 app through the real child-process
    transport. Checks runtime files after two builds and removes all test data.
.EXAMPLE
    pwsh -NoProfile -File tests/test-live-smoke-dotnet.ps1
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$live = Join-Path $PSScriptRoot 'live'
Import-Module (Join-Path $live 'model-routing-smoke-core.psm1') -Force
if (-not ((& dotnet --version).Trim().StartsWith('10.'))) { throw '.NET SDK 10 required.' }
$temporary = Join-Path ([IO.Path]::GetTempPath()) "routing-dotnet-contract-$([guid]::NewGuid().ToString('N'))"
[void](New-Item -ItemType Directory -Path $temporary)
try {
    $physical = Resolve-MRSmokePhysicalPath $temporary
    [void](New-Item -ItemType Directory -Path (Join-Path $physical 'project'))
    $initialPath = Join-Path $temporary 'project'
    if (-not $IsWindows) {
        $initialPath = Join-Path $physical 'alias'
        [void](New-Item -ItemType SymbolicLink -Path $initialPath -Target (Join-Path $physical 'project'))
    }
    $worktree = Resolve-MRSmokePhysicalPath $initialPath
    [IO.File]::WriteAllText((Join-Path $worktree 'NuGet.Config'),'<configuration><packageSources><clear /></packageSources></configuration>')
    [IO.File]::WriteAllText((Join-Path $worktree 'Probe.csproj'),'<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>')
    [IO.File]::WriteAllText((Join-Path $worktree 'Program.cs'),'System.Console.WriteLine("MODEL_ROUTING_OK");')
    $environment = @{DOTNET_CLI_HOME=$worktree;NUGET_PACKAGES=(Join-Path $worktree '.packages');DOTNET_CLI_TELEMETRY_OPTOUT='1';DOTNET_GENERATE_ASPNET_CERTIFICATE='false';MSBUILDDISABLENODEREUSE='1'}
    $common = @{ChildScript=(Join-Path $live 'invoke-smoke-child.ps1');Executable='dotnet';WorkingDirectory=$worktree;TimeoutSeconds=30;Environment=$environment}
    $project = Join-Path $worktree 'Probe.csproj'
    $build = Invoke-MRSmokeProcess @common -Arguments @('build',$project,'--configfile',(Join-Path $worktree 'NuGet.Config'),'-p:UseSharedCompilation=false')
    if ($build.exitCode -ne 0) { throw "Initial build failed: $($build.stderr)" }
    $project = Join-Path (Resolve-MRSmokePhysicalPath (Join-Path $temporary 'project')) 'Probe.csproj'
    $build = Invoke-MRSmokeProcess @common -Arguments @('build','--no-restore',$project,'-p:UseSharedCompilation=false')
    if ($build.exitCode -ne 0) { throw "Follow-up build failed: $($build.stderr)" }
    foreach ($name in @('Probe.runtimeconfig.json','Probe.deps.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $worktree "bin/Debug/net10.0/$name"))) { throw "Runtime artifact lost: $name" }
    }
    $run = Invoke-MRSmokeProcess @common -Arguments @('run','--project',$project,'--no-build','--no-restore')
    if ($run.exitCode -ne 0 -or $run.stdout.TrimEnd("`r","`n") -cne 'MODEL_ROUTING_OK') { throw "Output verification failed: $($run.stderr)" }
    'PASS: physical-path .NET build/rebuild/run regression; no models or package sources.'
} finally { Remove-Item -LiteralPath $temporary -Recurse -Force }
