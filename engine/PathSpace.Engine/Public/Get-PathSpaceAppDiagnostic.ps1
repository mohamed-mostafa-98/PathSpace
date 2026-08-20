function Get-PathSpaceAppDiagnostic {
    [CmdletBinding()]
    param([hashtable]$FixtureOutputs)
    $wslText = if($FixtureOutputs){$FixtureOutputs.wsl}else{try{(& wsl.exe --list --verbose 2>$null | Out-String)}catch{$null}}
    $dockerText = if($FixtureOutputs){$FixtureOutputs.docker}else{try{(& docker.exe system df 2>$null | Out-String)}catch{$null}}
    if($wslText){[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='wsl';available=$true;data=@(ConvertFrom-WslList $wslText);reason=$null}}else{[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='wsl';available=$false;data=@();reason='WSL command is unavailable or returned no distributions.'}}
    if($dockerText){[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='docker';available=$true;data=ConvertFrom-DockerSystemDf $dockerText;reason=$null}}else{[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='docker';available=$false;data=$null;reason='Docker engine is unavailable; no cleanup command was attempted.'}}
    if($FixtureOutputs){return}
    $notion = Join-Path $env:APPDATA 'Notion\Partitions'
    [pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='notion';available=[IO.Directory]::Exists($notion);data=@{path=$notion};reason='Confirm Notion synchronization before using its Reset local data control.'}
    $claudePackages = @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    [pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='claude';available=($claudePackages.Count -gt 0);data=$claudePackages;reason='Relocate only through copy, verification, junction, and retained rollback.'}
    try{$pagefiles=@(Get-CimInstance Win32_PageFileUsage -ErrorAction Stop);[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='pagefile';available=$true;data=$pagefiles;reason='Keep system-managed sizing unless measured memory pressure supports a change.'}}catch{[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='pagefile';available=$false;data=@();reason=$_.Exception.Message}}
    $hiber=Join-Path $env:SystemDrive 'hiberfil.sys';[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='hibernation';available=[IO.File]::Exists($hiber);data=@{path=$hiber;bytes=$(if([IO.File]::Exists($hiber)){([IO.FileInfo]::new($hiber)).Length}else{0})};reason='Disabling hibernation also disables Hibernate and may affect Fast Startup.'}
    try{$volumes=@(Get-Volume -ErrorAction Stop | Select-Object DriveLetter,FileSystemType,DriveType,HealthStatus,Size,SizeRemaining);[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='volume';available=$true;data=$volumes;reason='PathSpace uses the native Optimize-Volume command appropriate to the media.'}}catch{[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='volume';available=$false;data=@();reason=$_.Exception.Message}}
}
