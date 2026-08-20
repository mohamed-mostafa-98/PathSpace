#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'
$computer = Get-CimInstance Win32_ComputerSystem
$pagefile = Get-CimInstance Win32_PageFileUsage
$memory = Get-CimInstance Win32_OperatingSystem
$settings = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
$crash = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'

[pscustomobject]@{
    RAM_GB = [math]::Round($computer.TotalPhysicalMemory/1GB,2)
    AutomaticManagedPagefile = $computer.AutomaticManagedPagefile
    AvailableRAM_GB = [math]::Round($memory.FreePhysicalMemory/1MB,2)
    PagingFilesRegistry = $settings.PagingFiles -join '; '
    CrashDumpEnabled = $crash.CrashDumpEnabled
}

$pagefile | Select-Object Name,
    @{Name='AllocatedGB';Expression={[math]::Round($_.AllocatedBaseSize/1024,2)}},
    @{Name='CurrentUsageGB';Expression={[math]::Round($_.CurrentUsage/1024,2)}},
    @{Name='PeakUsageGB';Expression={[math]::Round($_.PeakUsage/1024,2)}}

Get-Counter '\Memory\Committed Bytes','\Memory\Commit Limit','\Memory\Available MBytes' |
    ForEach-Object {$_.CounterSamples | Select-Object Path,CookedValue}

