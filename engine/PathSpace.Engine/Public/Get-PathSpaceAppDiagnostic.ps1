function Get-PathSpaceAppDiagnostic {
    [CmdletBinding()]
    param([hashtable]$FixtureOutputs)
    $wslCommand = if($FixtureOutputs){$null}else{Invoke-DiagnosticCommand -FileName 'wsl.exe' -Arguments @('--list','--verbose') -TimeoutSeconds 10}
    $dockerCommand = if($FixtureOutputs){$null}else{Invoke-DiagnosticCommand -FileName 'docker.exe' -Arguments @('system','df') -TimeoutSeconds 10}
    $wslText = if($FixtureOutputs){$FixtureOutputs.wsl}elseif($wslCommand.available){$wslCommand.output}else{$null}
    $dockerText = if($FixtureOutputs){$FixtureOutputs.docker}elseif($dockerCommand.available){$dockerCommand.output}else{$null}
    $distributions=if($wslText){@(ConvertFrom-WslList $wslText)}else{@()}
    if($wslText){[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='wsl';available=$true;data=$distributions;reason='Each distribution owns a separate virtual disk. Unregistering a distribution is destructive.'}}else{[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='wsl';available=$false;data=@();reason='WSL command is unavailable or returned no distributions.'}}
    $nativeDocker=@()
    if(-not $FixtureOutputs){
        foreach($distribution in @($distributions|Where-Object{$_.name -ne 'docker-desktop'}|Select-Object -First 3)){
            if($distribution.name -notmatch '^[A-Za-z0-9_.-]+$'){continue}
            $native=Invoke-DiagnosticCommand -FileName 'wsl.exe' -Arguments @('-d',$distribution.name,'--','docker','system','df') -TimeoutSeconds 10
            if($native.available){$nativeDocker += [pscustomobject]@{distribution=$distribution.name;storage=ConvertFrom-DockerSystemDf $native.output}}
        }
    }
    if($dockerText -or $nativeDocker.Count -gt 0){[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='docker';available=$true;data=@{windowsContext=$(if($dockerText){ConvertFrom-DockerSystemDf $dockerText}else{$null});wslNative=$nativeDocker};reason='Windows Docker and Docker inside Ubuntu are separate owners. Named volumes may contain databases and are never auto-selected.'}}else{[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='docker';available=$false;data=$null;reason=$(if($dockerCommand){$dockerCommand.error}else{'Docker engine is unavailable; no cleanup command was attempted.'})}}
    if($FixtureOutputs){return}
    $notion = Join-Path $env:APPDATA 'Notion\Partitions';$notionData=$null
    if([IO.Directory]::Exists($notion)){$notionAggregate=Get-TreeAggregate -Root ([IO.DirectoryInfo]::new($notion)) -LargeFileBytes ([long]::MaxValue);$notionData=@{path=$notion;bytes=$notionAggregate.logicalBytes;warnings=$notionAggregate.warnings.Count}}
    [pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='notion';available=($null -ne $notionData);data=$notionData;reason='Confirm every page is synchronized, then prefer Notion Reset local data. Unknown application data is not deleted automatically.'}
    $claudeData=@();$packagesRoot=Join-Path $env:LOCALAPPDATA 'Packages'
    foreach($package in @(Get-ChildItem $packagesRoot -Directory -Filter 'Claude*' -ErrorAction SilentlyContinue)){
        $runtime=Join-Path $package.FullName 'LocalCache\Roaming\Claude\vm_bundles';if(-not [IO.Directory]::Exists($runtime)){continue}
        $item=Get-Item -LiteralPath $runtime -Force;$isJunction=(($item.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne 0)
        [long]$bytes=0;if(-not $isJunction){$bytes=(Get-TreeAggregate -Root ([IO.DirectoryInfo]::new($runtime)) -LargeFileBytes ([long]::MaxValue)).logicalBytes}
        $claudeData += [pscustomobject]@{package=$package.FullName;runtime=$runtime;bytes=$bytes;isJunction=$isJunction;target=@($item.Target)}
    }
    [pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='claude';available=($claudeData.Count -gt 0);data=$claudeData;reason='Relocate only through copy, ACL-preserving verification, retained rollback, and a verified junction.'}
    try{
        $pagefiles=@(Get-CimInstance Win32_PageFileUsage -ErrorAction Stop|ForEach-Object{[pscustomobject]@{name=$_.Name;allocatedBytes=[long]$_.AllocatedBaseSize*1MB;currentBytes=[long]$_.CurrentUsage*1MB;peakBytes=[long]$_.PeakUsage*1MB}})
        $memory=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $recovery=Get-CimInstance Win32_OSRecoveryConfiguration -ErrorAction SilentlyContinue
        $pageData=@{pagefiles=$pagefiles;totalVisibleMemoryBytes=[long]$memory.TotalVisibleMemorySize*1KB;freePhysicalMemoryBytes=[long]$memory.FreePhysicalMemory*1KB;automaticManagedPagefile=(Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).AutomaticManagedPagefile;debugInfoType=$recovery.DebugInfoType;dumpFile=$recovery.DebugFilePath;overwriteExistingDebugFile=$recovery.OverwriteExistingDebugFile}
        [pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='pagefile';available=$true;data=$pageData;reason='Keep system-managed sizing unless committed-memory pressure and crash-dump requirements support a change.'}
    }catch{[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='pagefile';available=$false;data=@();reason=$_.Exception.Message}}
    $hiber=Join-Path $env:SystemDrive 'hiberfil.sys';[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='hibernation';available=[IO.File]::Exists($hiber);data=@{path=$hiber;bytes=$(if([IO.File]::Exists($hiber)){([IO.FileInfo]::new($hiber)).Length}else{0})};reason='Disabling hibernation also disables Hibernate and may affect Fast Startup.'}
    try{$volumes=@(Get-Volume -ErrorAction Stop | Select-Object DriveLetter,FileSystemType,DriveType,HealthStatus,Size,SizeRemaining);$media=@(Get-PhysicalDisk -ErrorAction SilentlyContinue|Select-Object FriendlyName,MediaType,HealthStatus,Size);[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='volume';available=$true;data=@{volumes=$volumes;physicalMedia=$media};reason='PathSpace uses native Optimize-Volume; Windows selects retrim for SSD media and defragment behavior for HDD media.'}}catch{[pscustomobject]@{schemaVersion=1;kind='app.diagnostic';id='volume';available=$false;data=@();reason=$_.Exception.Message}}
}
