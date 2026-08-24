[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BaselineInstallerPath,
    [Parameter(Mandatory=$true)][string]$UpgradeInstallerPath
)
$ErrorActionPreference='Stop'
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Installer lifecycle validation must run from an elevated PowerShell session on a disposable clean host.'}
$baseline=(Resolve-Path -LiteralPath $BaselineInstallerPath).Path
$upgrade=(Resolve-Path -LiteralPath $UpgradeInstallerPath).Path
function Get-MsiIdentity([string]$Path){
    $installer=New-Object -ComObject WindowsInstaller.Installer
    $database=$installer.GetType().InvokeMember('OpenDatabase','InvokeMethod',$null,$installer,@($Path,0))
    $values=@{}
    foreach($property in @('ProductVersion','ProductCode','UpgradeCode')){
        $view=$database.OpenView("SELECT ``Value`` FROM ``Property`` WHERE ``Property``='$property'")
        $null=$view.Execute();$record=$view.Fetch();$values[$property]=$record.StringData(1)
        $null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($record);$null=$view.Close();$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($view)
    }
    $null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($database);$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($installer)
    [pscustomobject]$values
}
$baselineIdentity=Get-MsiIdentity $baseline
$upgradeIdentity=Get-MsiIdentity $upgrade
if($baselineIdentity.UpgradeCode -ne $upgradeIdentity.UpgradeCode){throw 'Baseline and upgrade MSI files do not share an upgrade identity.'}
if([version]$upgradeIdentity.ProductVersion -le [version]$baselineIdentity.ProductVersion){throw 'Upgrade MSI version must be higher than the baseline MSI version.'}
$logRoot=Join-Path $env:TEMP ("PathSpace-msi-lifecycle-"+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $logRoot | Out-Null
function Invoke-Msi([string[]]$Arguments,[string]$Operation){
    $process=Start-Process msiexec.exe -ArgumentList $Arguments -Wait -PassThru
    if($process.ExitCode -notin 0,3010){throw "$Operation failed with MSI exit code $($process.ExitCode)."}
}
try{
    Invoke-Msi @('/i',('"'+$baseline+'"'),'/qn','/norestart','/l*v',('"'+(Join-Path $logRoot 'install.log')+'"')) 'Baseline install'
    if(-not (Test-Path "$env:ProgramFiles\PathSpace\PathSpace.App.exe")){throw 'Baseline application file was not installed.'}
    if(-not (Test-Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\PathSpace.lnk")){throw 'Start-menu shortcut was not installed.'}
    if(-not (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($baselineIdentity.ProductCode)")){throw 'Baseline uninstall registration was not created.'}
    Invoke-Msi @('/i',('"'+$upgrade+'"'),'/qn','/norestart','/l*v',('"'+(Join-Path $logRoot 'upgrade.log')+'"')) 'Major upgrade'
    if(Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($baselineIdentity.ProductCode)"){throw 'Baseline product registration remained after major upgrade.'}
    if(-not (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($upgradeIdentity.ProductCode)")){throw 'Upgrade uninstall registration was not created.'}
    Invoke-Msi @('/x',('"'+$upgrade+'"'),'/qn','/norestart','/l*v',('"'+(Join-Path $logRoot 'uninstall.log')+'"')) 'Uninstall'
    if(Test-Path "$env:ProgramFiles\PathSpace\PathSpace.App.exe"){throw 'Application file remained after uninstall.'}
    if(Test-Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\PathSpace.lnk"){throw 'Start-menu shortcut remained after uninstall.'}
    if(Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($upgradeIdentity.ProductCode)"){throw 'Uninstall registration remained after uninstall.'}
} catch {
    foreach($candidate in @($upgrade,$baseline)){
        Start-Process msiexec.exe -ArgumentList @('/x',('"'+$candidate+'"'),'/qn','/norestart') -Wait -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Warning "Lifecycle logs were preserved at $logRoot"
    throw
}
Remove-Item -LiteralPath $logRoot -Recurse -Force
Write-Output 'Verified clean install, major upgrade, Start-menu identity, and uninstall.'
