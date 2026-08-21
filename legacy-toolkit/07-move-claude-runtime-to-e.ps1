[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [string]$Source=(Join-Path $env:LOCALAPPDATA 'Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\vm_bundles'),
    [string]$TargetRoot='E:\claude_data',
    [string]$BackupPath,
    [switch]$Rollback,
    [switch]$SkipVolumeValidation,
    [switch]$SkipClaudeStop
)
$ErrorActionPreference='Stop'
$Source=[IO.Path]::GetFullPath($Source)
$TargetRoot=[IO.Path]::GetFullPath($TargetRoot)
if(-not $BackupPath){$BackupPath="$Source.c-backup"}
$BackupPath=[IO.Path]::GetFullPath($BackupPath)
$target=Join-Path $TargetRoot (Split-Path $Source -Leaf)
if($Source.StartsWith('\\') -or $TargetRoot.StartsWith('\\')){throw 'Claude relocation requires local NTFS paths.'}
if([IO.Path]::GetPathRoot($Source) -eq $Source -or [IO.Path]::GetPathRoot($TargetRoot) -eq $TargetRoot){throw 'Drive roots cannot be relocation targets.'}
$sourcePrefix=$Source.TrimEnd('\')+'\';$targetPrefix=$TargetRoot.TrimEnd('\')+'\'
if($sourcePrefix.StartsWith($targetPrefix,[StringComparison]::OrdinalIgnoreCase) -or $targetPrefix.StartsWith($sourcePrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Source and target paths must not overlap.'}
if(($BackupPath.TrimEnd('\')+'\').StartsWith($sourcePrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'The rollback backup cannot be inside the source directory.'}
if($Rollback){
    if(-not (Test-Path -LiteralPath $BackupPath -PathType Container)){throw "Rollback backup was not found: $BackupPath"}
    $sourceItem=Get-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue
    if(-not $sourceItem -or $sourceItem.LinkType -ne 'Junction'){throw 'Rollback requires the source path to be the migration junction.'}
    if($PSCmdlet.ShouldProcess($Source,'Remove the verified junction and restore the retained Claude backup')){
        [IO.Directory]::Delete($Source)
        Move-Item -LiteralPath $BackupPath -Destination $Source
    }
    return [pscustomobject]@{Status='rolledBack';Source=$Source;Target=$target;Backup=$BackupPath}
}
if(-not (Test-Path -LiteralPath $Source -PathType Container)){throw "Claude runtime source was not found: $Source"}
$sourceItem=Get-Item -LiteralPath $Source -Force
if($sourceItem.LinkType -eq 'Junction'){throw 'The Claude runtime path is already a junction; nothing was changed.'}
if(Test-Path -LiteralPath $BackupPath){throw "Rollback backup already exists: $BackupPath"}
if(-not $SkipVolumeValidation){
    $drive=[IO.Path]::GetPathRoot($TargetRoot).TrimEnd('\').TrimEnd(':')
    $volume=Get-Volume -DriveLetter $drive
    if($volume.FileSystem -ne 'NTFS'){throw "The target must be NTFS. Detected filesystem: $($volume.FileSystem)"}
}
$sourceFiles=@(Get-ChildItem -LiteralPath $Source -Force -File -Recurse -ErrorAction Stop)
[long]$sourceBytes=($sourceFiles|Measure-Object Length -Sum).Sum
if(-not $SkipVolumeValidation){
    $targetDrive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($TargetRoot))
    if($targetDrive.AvailableFreeSpace -lt [long]($sourceBytes*1.1)){throw 'Insufficient free space for the copy and verification stage.'}
}
if(-not $SkipClaudeStop){Get-Process -Name Claude -ErrorAction SilentlyContinue|Stop-Process -Force}
if(-not $PSCmdlet.ShouldProcess($Source,"Copy to '$target', verify, retain rollback backup, and create a junction")){
    return [pscustomobject]@{Status='preview';Source=$Source;Target=$target;Backup=$BackupPath;Bytes=$sourceBytes}
}
New-Item -ItemType Directory -Path $TargetRoot -Force|Out-Null
New-Item -ItemType Directory -Path $target -Force|Out-Null
& robocopy.exe $Source $target /E /COPY:DATS /DCOPY:DAT /R:1 /W:1 /XJ|Out-Null
if($LASTEXITCODE -ge 8){throw "Robocopy failed with exit code $LASTEXITCODE. The original remains unchanged."}
$targetFiles=@(Get-ChildItem -LiteralPath $target -Force -File -Recurse -ErrorAction Stop)
[long]$targetBytes=($targetFiles|Measure-Object Length -Sum).Sum
if($targetBytes -ne $sourceBytes -or $targetFiles.Count -ne $sourceFiles.Count){throw 'Copy verification failed; the original remains unchanged.'}
Move-Item -LiteralPath $Source -Destination $BackupPath
try{New-Item -ItemType Junction -Path $Source -Target $target|Out-Null}
catch{Move-Item -LiteralPath $BackupPath -Destination $Source;throw}
$junction=Get-Item -LiteralPath $Source -Force
if($junction.LinkType -ne 'Junction' -or [IO.Path]::GetFullPath([string]$junction.Target) -ne [IO.Path]::GetFullPath($target)){
    if(Test-Path -LiteralPath $Source){[IO.Directory]::Delete($Source)}
    Move-Item -LiteralPath $BackupPath -Destination $Source
    throw 'Junction verification failed; the original was restored.'
}
[pscustomobject]@{Status='staged';Source=$Source;Target=$target;Backup=$BackupPath;Bytes=$sourceBytes;RollbackRetained=$true}
