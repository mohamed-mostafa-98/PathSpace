[CmdletBinding()]
param(
    [string]$Configuration='Release',
    [string]$DotNetPath,
    [string]$ArtifactPath,
    [switch]$SelfContained
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifact=if($ArtifactPath){$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ArtifactPath)}else{Join-Path $projectRoot 'artifacts\PathSpace-win-x64'}
$dotnet=$DotNetPath
if(-not $dotnet){$dotnet=(Get-Command dotnet -ErrorAction SilentlyContinue).Source}
if($dotnet -and -not [IO.File]::Exists($dotnet)){throw "The supplied .NET executable does not exist: $dotnet"}
if($dotnet -and -not (& $dotnet --list-sdks)){$dotnet=$null}
if(-not $dotnet){$local=Resolve-Path (Join-Path $projectRoot '..\.dotnet\dotnet.exe') -ErrorAction SilentlyContinue;if($local){$dotnet=$local.Path}}
if(-not $dotnet){throw '.NET 8 SDK was not found.'}
if(Test-Path $artifact){Remove-Item -LiteralPath $artifact -Recurse -Force}
New-Item -ItemType Directory -Path $artifact | Out-Null
& $dotnet publish (Join-Path $projectRoot 'src\PathSpace.App\PathSpace.App.csproj') -c $Configuration -r win-x64 --self-contained $SelfContained.IsPresent -o $artifact
if($LASTEXITCODE -ne 0){throw 'GUI publish failed.'}
$worker=Join-Path $artifact 'worker';New-Item -ItemType Directory -Path $worker | Out-Null
& $dotnet publish (Join-Path $projectRoot 'src\PathSpace.Worker\PathSpace.Worker.csproj') -c $Configuration -r win-x64 --self-contained $SelfContained.IsPresent -o $worker
if($LASTEXITCODE -ne 0){throw 'Worker publish failed.'}
if($SelfContained){
    $deps=Get-Content -Raw (Join-Path $artifact 'PathSpace.App.deps.json') | ConvertFrom-Json
    $runtimePack=@($deps.libraries.psobject.Properties.Name | Where-Object {$_ -like 'runtimepack.Microsoft.NETCore.App.Runtime.win-x64/*'})[0]
    if(-not $runtimePack){throw 'Published runtime-pack identity was not found.'}
    $runtimeVersion=($runtimePack -split '/')[-1]
    $nugetRoot=((& $dotnet nuget locals global-packages --list) -replace '^global-packages:\s*','').Trim()
    $legal=@{
        'DOTNET-RUNTIME-LICENSE.txt'=Join-Path $nugetRoot "microsoft.netcore.app.runtime.win-x64\$runtimeVersion\LICENSE.TXT"
        'DOTNET-RUNTIME-THIRD-PARTY-NOTICES.txt'=Join-Path $nugetRoot "microsoft.netcore.app.runtime.win-x64\$runtimeVersion\THIRD-PARTY-NOTICES.TXT"
        'DOTNET-WINDOWSDESKTOP-LICENSE.txt'=Join-Path $nugetRoot "microsoft.windowsdesktop.app.runtime.win-x64\$runtimeVersion\LICENSE"
    }
    foreach($entry in $legal.GetEnumerator()){
        if(-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)){throw "Embedded runtime legal file was not found: $($entry.Value)"}
        Copy-Item -LiteralPath $entry.Value -Destination (Join-Path $artifact $entry.Key)
    }
}
foreach($name in @('engine','schemas','cli','legacy-toolkit')){Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $artifact -Recurse -Force}
Copy-Item -LiteralPath (Join-Path $projectRoot 'engine') -Destination $worker -Recurse -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'cli') -Destination $worker -Recurse -Force
foreach($name in @('README.md','PROJECT_STATUS.md','CONTRIBUTING.md','CHANGELOG.md','LICENSE','THIRD-PARTY-NOTICES.md')){
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $artifact
}
foreach($name in @('pathspace-icon.png','pathspace.ico')){Copy-Item -LiteralPath (Join-Path $projectRoot "assets\$name") -Destination $artifact}
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs') -Destination $artifact -Recurse -Force
& (Join-Path $PSScriptRoot 'new-package-checksums.ps1') -ArtifactPath $artifact | Out-Null
Write-Output $artifact
