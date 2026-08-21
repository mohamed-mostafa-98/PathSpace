[CmdletBinding()]
param([string]$DotNetPath)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $DotNetPath){$DotNetPath=(Get-Command dotnet -ErrorAction SilentlyContinue).Source}
if(-not $DotNetPath -or -not [IO.File]::Exists($DotNetPath)){throw 'A valid .NET 8 SDK host is required through -DotNetPath or PATH.'}
& (Join-Path $PSScriptRoot 'build-portable.ps1') -DotNetPath $DotNetPath
if($LASTEXITCODE -ne 0){throw 'Portable package build failed.'}
$env:PATHSPACE_RUN_PACKAGED_E2E='1'
$resultsDirectory=Join-Path $projectRoot 'artifacts\test-results'
New-Item -ItemType Directory -Path $resultsDirectory -Force | Out-Null
try {
    & $DotNetPath test (Join-Path $projectRoot 'tests\PathSpace.E2E.Tests\PathSpace.E2E.Tests.csproj') -c Release --logger 'console;verbosity=normal' --logger 'trx;LogFileName=PathSpace-packaged-gui.trx' --results-directory $resultsDirectory
    if($LASTEXITCODE -ne 0){throw 'Packaged GUI E2E tests failed.'}
} finally { Remove-Item Env:PATHSPACE_RUN_PACKAGED_E2E -ErrorAction SilentlyContinue }
