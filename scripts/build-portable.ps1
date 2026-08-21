[CmdletBinding()]
param([string]$Configuration='Release')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifact=Join-Path $projectRoot 'artifacts\PathSpace-win-x64'
$dotnet=(Get-Command dotnet -ErrorAction SilentlyContinue).Source
if($dotnet -and -not (& $dotnet --list-sdks)){$dotnet=$null}
if(-not $dotnet){$local=Resolve-Path (Join-Path $projectRoot '..\.dotnet\dotnet.exe') -ErrorAction SilentlyContinue;if($local){$dotnet=$local.Path}}
if(-not $dotnet){throw '.NET 8 SDK was not found.'}
if(Test-Path $artifact){Remove-Item -LiteralPath $artifact -Recurse -Force}
New-Item -ItemType Directory -Path $artifact | Out-Null
& $dotnet publish (Join-Path $projectRoot 'src\PathSpace.App\PathSpace.App.csproj') -c $Configuration -r win-x64 --self-contained false -o $artifact
if($LASTEXITCODE -ne 0){throw 'GUI publish failed.'}
$worker=Join-Path $artifact 'worker';New-Item -ItemType Directory -Path $worker | Out-Null
& $dotnet publish (Join-Path $projectRoot 'src\PathSpace.Worker\PathSpace.Worker.csproj') -c $Configuration -r win-x64 --self-contained false -o $worker
if($LASTEXITCODE -ne 0){throw 'Worker publish failed.'}
foreach($name in @('engine','schemas','cli','legacy-toolkit')){Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $artifact -Recurse -Force}
Copy-Item -LiteralPath (Join-Path $projectRoot 'engine') -Destination $worker -Recurse -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'cli') -Destination $worker -Recurse -Force
foreach($name in @('README.md','PROJECT_STATUS.md','CONTRIBUTING.md','CHANGELOG.md')){
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $artifact
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs') -Destination $artifact -Recurse -Force
Get-ChildItem -LiteralPath $artifact -Recurse -File | Get-FileHash -Algorithm SHA256 | ForEach-Object {"$($_.Hash)  $($_.Path.Substring($artifact.Length+1))"} | Set-Content (Join-Path $artifact 'SHA256SUMS.txt') -Encoding UTF8
Write-Output $artifact
