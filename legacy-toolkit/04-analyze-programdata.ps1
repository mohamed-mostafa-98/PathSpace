#Requires -RunAsAdministrator
[CmdletBinding()]
param([string]$ReportPath)
$ErrorActionPreference = 'SilentlyContinue'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'programdata-report.txt'
}
$results = Get-ChildItem C:\ProgramData -Force -Directory | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Force -File -Recurse -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum).Sum
    [pscustomobject]@{Folder=$_.FullName;SizeGB=[math]::Round($size/1GB,2)}
} | Sort-Object SizeGB -Descending
$results | Format-Table -AutoSize | Out-String | Set-Content -LiteralPath $ReportPath
$results | Format-Table -AutoSize
Write-Host "Report saved to: $ReportPath"

