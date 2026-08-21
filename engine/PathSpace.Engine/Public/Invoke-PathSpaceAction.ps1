function Invoke-PathSpaceAction {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$ActionId, [hashtable]$Parameters=@{}, [switch]$DryRun, [switch]$Confirmed)
    $preview = Get-PathSpaceActionPreview -ActionId $ActionId -Parameters $Parameters
    if (-not $DryRun -and -not $Confirmed) { throw 'Execution requires explicit -Confirmed acknowledgement after preview.' }
    if ($DryRun) {
        return [pscustomobject]@{ schemaVersion=1; kind='action.result'; actionId=$ActionId; status='dryRun'; recoveredBytes=[long]0; targetsProcessed=[long]0; targetsSkipped=[long]0; targets=$preview.targets; messages=@('No files were changed during dry-run.') }
    }

    $measurementPath = if ($ActionId -in @('temp.user','temp.windows','cache.npm','volume.optimize') -and $preview.targets.Count -gt 0) { [string]$preview.targets[0].path } else { "$env:SystemDrive\" }
    $measurementRoot = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($measurementPath))
    [long]$freeBefore = if ($measurementRoot) { ([IO.DriveInfo]::new($measurementRoot)).AvailableFreeSpace } else { 0 }

    [long]$processed = 0
    [long]$skipped = 0
    $messages = New-Object 'System.Collections.Generic.List[string]'
    try {
        switch ($ActionId) {
            { $_ -in @('temp.user','temp.windows','cache.npm') } {
                $root = $preview.targets[0].path
                $directory = Resolve-SafeLocalPath -LiteralPath $root
                foreach ($item in Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue) {
                    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { $skipped++; $messages.Add("Skipped reparse target: $($item.FullName)"); continue }
                    try { Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop; $processed++ }
                    catch { $skipped++; $messages.Add("Skipped locked or inaccessible target: $($item.FullName)") }
                }
            }
            'recycle.currentUser' { Clear-RecycleBin -Force -ErrorAction Stop; $processed++ }
            'windows.componentCleanup' { & dism.exe @('/Online','/Cleanup-Image','/StartComponentCleanup'); if ($LASTEXITCODE -ne 0) { throw "DISM exited with code $LASTEXITCODE." }; $processed++ }
            'power.hibernate' { & powercfg.exe @('/hibernate','off'); if ($LASTEXITCODE -ne 0) { throw "powercfg exited with code $LASTEXITCODE." }; $processed++ }
            'volume.optimize' { Optimize-Volume -DriveLetter ([string]$Parameters.DriveLetter).ToUpperInvariant() -Verbose -ErrorAction Stop; $processed++ }
        }
    }
    catch { $messages.Add($_.Exception.Message); $skipped++ }
    $after = Get-PathSpaceActionPreview -ActionId $ActionId -Parameters $Parameters
    [long]$freeAfter = if ($measurementRoot) { ([IO.DriveInfo]::new($measurementRoot)).AvailableFreeSpace } else { $freeBefore }
    [long]$removedFromTargets = [Math]::Max(0, $preview.estimatedBytes - $after.estimatedBytes)
    [long]$recovered = [Math]::Max(0, $freeAfter - $freeBefore)
    $messages.Add("Post-action target measurement changed by $removedFromTargets bytes; available disk space changed by $recovered bytes.")
    [pscustomobject]@{ schemaVersion=1; kind='action.result'; actionId=$ActionId; status=$(if($skipped -gt 0){'partial'}else{'completed'}); recoveredBytes=$recovered; targetsProcessed=$processed; targetsSkipped=$skipped; targets=$preview.targets; messages=@($messages.ToArray()) }
}
