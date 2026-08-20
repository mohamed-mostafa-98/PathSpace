#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$source = 'C:\Users\DELL\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\vm_bundles'
$targetRoot = 'E:\claude_data'
$target = 'E:\claude_data\vm_bundles'
$backup = 'C:\Users\DELL\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\vm_bundles.c-backup'

$volume = Get-Volume -DriveLetter E
if ($volume.FileSystem -ne 'NTFS') {
    throw "E: must be NTFS. Detected filesystem: $($volume.FileSystem)"
}

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Claude runtime source was not found: $source"
}

$sourceItem = Get-Item -LiteralPath $source -Force
if ($sourceItem.LinkType -eq 'Junction') {
    throw 'The Claude runtime path is already a junction; nothing was changed.'
}

if (Test-Path -LiteralPath $backup) {
    throw "Rollback backup already exists: $backup"
}

$sourceBytes = (Get-ChildItem -LiteralPath $source -Force -File -Recurse -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum).Sum
$requiredBytes = [int64]($sourceBytes * 1.1)
if ($volume.SizeRemaining -lt $requiredBytes) {
    throw "Insufficient free space on E:. Need about $([math]::Round($requiredBytes/1GB,2)) GB."
}

Get-Process -Name 'Claude' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
New-Item -ItemType Directory -Path $target -Force | Out-Null

Write-Host "Copying $([math]::Round($sourceBytes/1GB,2)) GB to E:. This can take several minutes..."
& robocopy.exe $source $target /E /COPY:DATS /DCOPY:DAT /R:1 /W:1 /XJ
$robocopyCode = $LASTEXITCODE
if ($robocopyCode -ge 8) {
    throw "Robocopy failed with exit code $robocopyCode. The original remains unchanged."
}

$targetBytes = (Get-ChildItem -LiteralPath $target -Force -File -Recurse -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum).Sum
if ($targetBytes -lt $sourceBytes) {
    throw "Verification failed: target contains fewer bytes than source. The original remains unchanged."
}

Rename-Item -LiteralPath $source -NewName 'vm_bundles.c-backup'
try {
    New-Item -ItemType Junction -Path $source -Target $target | Out-Null
} catch {
    Rename-Item -LiteralPath $backup -NewName 'vm_bundles'
    throw
}

$junction = Get-Item -LiteralPath $source -Force
Write-Host ''
Write-Host 'Move staged successfully.'
Write-Host "Junction: $($junction.FullName) -> $($junction.Target)"
Write-Host "Rollback backup retained at: $backup"
Write-Host 'Start Claude and test it. Do not delete the backup yet.'
