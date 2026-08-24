[CmdletBinding()]
param([string]$InstallerPath,[string]$ExpectedVersion)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $ExpectedVersion){$ExpectedVersion=([xml](Get-Content -Raw (Join-Path $projectRoot 'Directory.Build.props'))).Project.PropertyGroup.Version}
if(-not $InstallerPath){$InstallerPath=Join-Path $projectRoot "artifacts\installer\PathSpace-$ExpectedVersion-win-x64.msi"}
$msi=(Resolve-Path -LiteralPath $InstallerPath -ErrorAction Stop).Path
$installer=New-Object -ComObject WindowsInstaller.Installer
$database=$installer.GetType().InvokeMember('OpenDatabase','InvokeMethod',$null,$installer,@($msi,0))
function Get-MsiValue([string]$Query){
    $view=$database.OpenView($Query)
    try{
        $null=$view.Execute();$record=$view.Fetch()
        if($record){$value=$record.StringData(1);$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($record);$value}
    } finally {$null=$view.Close();$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($view)}
}
function Get-MsiValues([string]$Query){
    $view=$database.OpenView($Query)
    try{
        $null=$view.Execute()
        while($record=$view.Fetch()){$value=$record.StringData(1);$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($record);$value}
    } finally {$null=$view.Close();$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($view)}
}
$expected=@{ProductName='PathSpace';ProductVersion=$ExpectedVersion;Manufacturer='PathSpace Contributors';UpgradeCode='{A24ED348-102B-4E29-B194-B2E9B13619E5}'}
foreach($entry in $expected.GetEnumerator()){
    $actual=Get-MsiValue "SELECT ``Value`` FROM ``Property`` WHERE ``Property``='$($entry.Key)'"
    if($actual -ne $entry.Value){throw "MSI $($entry.Key) was '$actual'; expected '$($entry.Value)'."}
}
$fileNames=@(Get-MsiValues 'SELECT `FileName` FROM `File`' | ForEach-Object {($_ -split '\|')[-1]})
foreach($file in @('PathSpace.App.exe','coreclr.dll','hostfxr.dll','PresentationFramework.dll','PathSpace.Worker.exe','DOTNET-RUNTIME-LICENSE.txt','DOTNET-RUNTIME-THIRD-PARTY-NOTICES.txt','DOTNET-WINDOWSDESKTOP-LICENSE.txt')){
    if($file -notin $fileNames){throw "MSI payload is missing $file."}
}
$shortcutNames=@(Get-MsiValues 'SELECT `Name` FROM `Shortcut`' | ForEach-Object {($_ -split '\|')[-1]})
if('PathSpace' -notin $shortcutNames){throw 'MSI Start-menu shortcut is missing.'}
$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($database)
$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($installer)
$database=$installer=$null

$extract=Join-Path ([IO.Path]::GetTempPath()) ("PathSpace-msi-"+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $extract | Out-Null
try{
    $process=Start-Process msiexec.exe -ArgumentList @('/a',('"'+$msi+'"'),'/qn',('TARGETDIR="'+$extract+'"')) -Wait -PassThru
    if($process.ExitCode -ne 0){throw "MSI administrative extraction failed with exit code $($process.ExitCode)."}
    $image=Join-Path $extract 'PFiles64\PathSpace'
    foreach($file in @('PathSpace.App.exe','coreclr.dll','worker\PathSpace.Worker.exe','DOTNET-RUNTIME-LICENSE.txt','DOTNET-RUNTIME-THIRD-PARTY-NOTICES.txt','DOTNET-WINDOWSDESKTOP-LICENSE.txt')){
        if(-not (Test-Path -LiteralPath (Join-Path $image $file) -PathType Leaf)){throw "Extracted MSI payload is missing $file."}
    }
} finally {Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue}
Write-Output "Verified MSI metadata, upgrade identity, Start-menu shortcut, embedded runtime, and administrative extraction: $msi"
