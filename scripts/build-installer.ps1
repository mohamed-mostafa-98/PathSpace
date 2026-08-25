[CmdletBinding()]
param(
    [string]$Configuration='Release',
    [string]$DotNetPath,
    [string]$Version,
    [string]$PayloadPath,
    [string]$OutputPath,
    [switch]$SkipPayloadBuild
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $Version){$Version=([xml](Get-Content -Raw (Join-Path $projectRoot 'Directory.Build.props'))).Project.PropertyGroup.Version}
if($Version -notmatch '^\d+\.\d+\.\d+$'){throw "MSI version must contain three numeric fields: $Version"}
$sha=[Security.Cryptography.SHA256]::Create()
try{$productCode=[guid]::new([byte[]]$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("PathSpace:$Version"))[0..15])}finally{$sha.Dispose()}
$dotnet=$DotNetPath
if(-not $dotnet){$dotnet=(Get-Command dotnet -ErrorAction SilentlyContinue).Source}
if($dotnet -and -not (& $dotnet --list-sdks)){$dotnet=$null}
if(-not $dotnet){throw '.NET 8 SDK was not found. Supply -DotNetPath when it is installed privately.'}

$buildRoot=Join-Path $projectRoot 'artifacts\installer-build'
$customOutput=[bool]$OutputPath
$outputRoot=if($customOutput){$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)}else{Join-Path $projectRoot 'artifacts\installer'}
$payload=if($PayloadPath){$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PayloadPath)}else{Join-Path $buildRoot 'payload'}
$output=Join-Path $outputRoot "PathSpace-$Version-win-x64.msi"
if(-not $SkipPayloadBuild -and (Test-Path $buildRoot)){Remove-Item -LiteralPath $buildRoot -Recurse -Force}
if($customOutput -and (Test-Path $outputRoot)){throw 'Custom installer output path must not already exist.'}
if(-not $customOutput -and (Test-Path $outputRoot)){Remove-Item -LiteralPath $outputRoot -Recurse -Force}
New-Item -ItemType Directory -Force -Path $buildRoot,$outputRoot | Out-Null
$intermediate=Join-Path $buildRoot 'obj'
if(Test-Path $intermediate){Remove-Item -LiteralPath $intermediate -Recurse -Force}

if(-not $SkipPayloadBuild){& (Join-Path $PSScriptRoot 'build-portable.ps1') -Configuration $Configuration -DotNetPath $dotnet -ArtifactPath $payload -SelfContained}
if(-not (Test-Path -LiteralPath $payload -PathType Container)){throw "Installer payload directory was not found: $payload"}
foreach($required in @('PathSpace.App.exe','coreclr.dll','hostfxr.dll','PresentationFramework.dll','DOTNET-RUNTIME-LICENSE.txt','DOTNET-RUNTIME-THIRD-PARTY-NOTICES.txt','DOTNET-WINDOWSDESKTOP-LICENSE.txt')){
    if(-not (Test-Path -LiteralPath (Join-Path $payload $required) -PathType Leaf)){throw "Self-contained installer payload is missing $required."}
}

Push-Location $projectRoot
try {
    & $dotnet tool restore
    if($LASTEXITCODE -ne 0){throw 'WiX tool restore failed.'}
    & $dotnet tool run wix -- build '.\installer\Package.wxs' -arch x64 -d "Payload=$payload" -d "Version=$Version" -d "ProductCode=$($productCode.ToString('D'))" -intermediatefolder $intermediate -pdbtype none -out $output
    if($LASTEXITCODE -ne 0){throw 'MSI build failed.'}
    & $dotnet tool run wix -- msi validate $output
    if($LASTEXITCODE -ne 0){throw 'MSI ICE validation failed.'}
} finally {Pop-Location}
if(-not (Test-Path -LiteralPath $output -PathType Leaf)){throw 'MSI output was not created.'}
& (Join-Path $PSScriptRoot 'new-package-checksums.ps1') -ArtifactPath $outputRoot | Out-Null
Write-Output $output
