#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$DisableHibernation,
    [string]$ReportPath
)

$ErrorActionPreference = 'Continue'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath 'cleanup-c-drive-report.txt'
}
Start-Transcript -LiteralPath $ReportPath -Force | Out-Null

function Get-FreeSpace {
    $drive = Get-PSDrive -Name C
    [pscustomobject]@{
        UsedGB = [math]::Round($drive.Used / 1GB, 2)
        FreeGB = [math]::Round($drive.Free / 1GB, 2)
    }
}

function Clear-DisposableFolder {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }

    $before = (Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum

    Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    $after = (Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum

    [pscustomobject]@{
        Target      = $Path
        RecoveredGB = [math]::Round(($before - $after) / 1GB, 3)
        RemainingGB = [math]::Round($after / 1GB, 3)
    }
}

Write-Host 'C: space before cleanup:'
Get-FreeSpace | Format-Table -AutoSize

Write-Host 'Cleaning disposable temporary files (locked files are skipped)...'
Clear-DisposableFolder -Path (Join-Path $env:LOCALAPPDATA 'Temp') | Format-Table -AutoSize
Clear-DisposableFolder -Path (Join-Path $env:WINDIR 'Temp') | Format-Table -AutoSize

Write-Host 'Emptying the current user Recycle Bin...'
Clear-RecycleBin -DriveLetter C -Force -ErrorAction SilentlyContinue

Write-Host 'Cleaning superseded Windows component files...'
Dism.exe /Online /Cleanup-Image /StartComponentCleanup

if ($DisableHibernation) {
    Write-Host 'Disabling hibernation and removing hiberfil.sys...'
    powercfg.exe /hibernate off
}

Write-Host 'Shadow-copy storage report (report only; no restore points removed):'
vssadmin.exe list shadowstorage

Write-Host 'Windows component-store report:'
Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore

Write-Host 'C: space after cleanup:'
Get-FreeSpace | Format-Table -AutoSize

Write-Host 'Cleanup complete. The pagefile and application data were not changed.'
Stop-Transcript | Out-Null
Write-Host "Report saved to: $ReportPath"
Read-Host 'Press Enter to close this window'
