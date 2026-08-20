function Get-TreeAggregate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [IO.DirectoryInfo] $Root,

        [Parameter(Mandatory = $true)]
        [long] $LargeFileBytes,

        [string] $CancellationFile,

        [scriptblock] $ProgressCallback
    )

    [long] $logicalBytes = 0
    [long] $fileCount = 0
    [long] $directoryCount = 0
    $cancelled = $false
    $warnings = New-Object 'System.Collections.Generic.List[object]'
    $largeFiles = New-Object 'System.Collections.Generic.List[object]'
    $aggregateMap = @{}
    $stack = New-Object 'System.Collections.Generic.Stack[object]'
    $stack.Push([pscustomobject]@{ Directory = $Root; AggregatePath = $Root.FullName })
    $lastProgress = [DateTime]::UtcNow.AddSeconds(-1)

    while ($stack.Count -gt 0) {
        if ($CancellationFile -and [IO.File]::Exists($CancellationFile)) {
            $cancelled = $true
            break
        }

        $work = $stack.Pop()
        $directory = $work.Directory
        $aggregatePath = [string] $work.AggregatePath
        if (-not $aggregateMap.ContainsKey($aggregatePath)) {
            $aggregateMap[$aggregatePath] = [pscustomobject]@{
                path = $aggregatePath
                logicalBytes = [long] 0
                fileCount = [long] 0
                directoryCount = [long] 0
            }
        }
        $aggregate = $aggregateMap[$aggregatePath]

        try {
            foreach ($file in $directory.EnumerateFiles()) {
                if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    $warnings.Add([pscustomobject]@{ path=$file.FullName; code='reparse.skipped'; message='Reparse-point file skipped.' })
                    continue
                }

                [long] $length = $file.Length
                $logicalBytes += $length
                $fileCount++
                $aggregate.logicalBytes += $length
                $aggregate.fileCount++
                if ($length -ge $LargeFileBytes) {
                    $largeFiles.Add([pscustomobject]@{
                        path = $file.FullName
                        logicalBytes = $length
                        lastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('o')
                    })
                }
            }
        }
        catch {
            $warnings.Add([pscustomobject]@{ path=$directory.FullName; code='enumeration.files'; message=$_.Exception.Message })
        }

        try {
            foreach ($child in $directory.EnumerateDirectories()) {
                if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    $warnings.Add([pscustomobject]@{ path=$child.FullName; code='reparse.skipped'; message='Reparse-point directory skipped.' })
                    continue
                }

                $directoryCount++
                $childAggregatePath = if ($directory.FullName -eq $Root.FullName) { $child.FullName } else { $aggregatePath }
                if (-not $aggregateMap.ContainsKey($childAggregatePath)) {
                    $aggregateMap[$childAggregatePath] = [pscustomobject]@{
                        path = $childAggregatePath
                        logicalBytes = [long] 0
                        fileCount = [long] 0
                        directoryCount = [long] 0
                    }
                }
                $aggregateMap[$childAggregatePath].directoryCount++
                $stack.Push([pscustomobject]@{ Directory=$child; AggregatePath=$childAggregatePath })
            }
        }
        catch {
            $warnings.Add([pscustomobject]@{ path=$directory.FullName; code='enumeration.directories'; message=$_.Exception.Message })
        }

        if ($ProgressCallback -and ([DateTime]::UtcNow - $lastProgress).TotalMilliseconds -ge 250) {
            & $ProgressCallback $directory.FullName $logicalBytes $fileCount $directoryCount | Out-Null
            $lastProgress = [DateTime]::UtcNow
        }
    }

    [pscustomobject]@{
        complete = -not $cancelled
        cancelled = $cancelled
        logicalBytes = $logicalBytes
        fileCount = $fileCount
        directoryCount = $directoryCount
        aggregates = @($aggregateMap.Values | Sort-Object logicalBytes -Descending)
        largeFiles = @($largeFiles.ToArray() | Sort-Object logicalBytes -Descending)
        warnings = @($warnings.ToArray())
    }
}
