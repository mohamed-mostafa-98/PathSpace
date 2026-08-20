function Invoke-PathSpaceScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $LiteralPath,

        [ValidateRange(1, [long]::MaxValue)]
        [long] $LargeFileBytes = 1GB,

        [string] $CancellationFile
    )

    $root = Resolve-SafeLocalPath -LiteralPath $LiteralPath
    $scanId = [Guid]::NewGuid().ToString('D')
    $progressAction = {
        param($currentPath, $logicalBytes, $fileCount, $directoryCount)
        $json = [pscustomobject]@{
            schemaVersion = 1
            kind = 'scan.progress'
            scanId = $scanId
            currentPath = $currentPath
            logicalBytes = [long] $logicalBytes
            fileCount = [long] $fileCount
            directoryCount = [long] $directoryCount
        } | Write-JsonLine
        [Console]::Out.WriteLine($json)
    }

    $result = Get-TreeAggregate -Root $root -LargeFileBytes $LargeFileBytes -CancellationFile $CancellationFile -ProgressCallback $progressAction

    [pscustomobject]@{
        schemaVersion = 1
        kind = 'scan.snapshot'
        scanId = $scanId
        targetPath = $root.FullName
        complete = $result.complete
        cancelled = $result.cancelled
        logicalBytes = $result.logicalBytes
        fileCount = $result.fileCount
        directoryCount = $result.directoryCount
        aggregates = $result.aggregates
        largeFiles = $result.largeFiles
        warnings = $result.warnings
    } | Write-JsonLine
}
