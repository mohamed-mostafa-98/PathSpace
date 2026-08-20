function Get-PathSpaceRecommendation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject] $Snapshot,

        [psobject] $Diagnostics
    )

    if (-not $Snapshot.complete) {
        return [pscustomobject]@{
            schemaVersion = 1
            kind = 'recommendation'
            id = 'analysis.incomplete'
            title = 'Analysis is incomplete'
            summary = 'Finish a complete scan before considering cleanup actions.'
            evidence = @('The scan completion flag is false.')
            estimatedMinBytes = [long] 0
            estimatedMaxBytes = [long] 0
            risk = 'Low'
            reversibility = 'Reversible'
            requiresElevation = $false
            priority = 0
            actionable = $false
        }
    }

    $rules = @(
        [pscustomobject]@{ id='temp.user'; pattern='[\\/]AppData[\\/]Local[\\/]Temp$'; title='Review user temporary files'; summary='Preview and remove disposable per-user temporary files.'; priority=10; risk='Low'; reversibility='Reversible'; elevation=$false; minFactor=0.5 },
        [pscustomobject]@{ id='cache.npm'; pattern='[\\/]npm-cache$'; title='Clear npm download cache'; summary='Verify and clear the rebuildable npm package cache.'; priority=20; risk='Low'; reversibility='Reversible'; elevation=$false; minFactor=0.8 },
        [pscustomobject]@{ id='cache.browser'; pattern='[\\/](Cache|Code Cache|GPUCache)$'; title='Review browser caches'; summary='Clear cached files through the owning browser when possible.'; priority=30; risk='Low'; reversibility='Reversible'; elevation=$false; minFactor=0.5 },
        [pscustomobject]@{ id='app.notion'; pattern='[\\/]Notion[\\/]Partitions$'; title='Review Notion local partitions'; summary='Confirm synchronization, then use Notion reset controls rather than deleting application data manually.'; priority=40; risk='Medium'; reversibility='BackupRecommended'; elevation=$false; minFactor=0.25 }
    )

    $recommendations = New-Object 'System.Collections.Generic.List[object]'
    foreach ($rule in $rules) {
        $matches = @($Snapshot.aggregates | Where-Object { $_.path -match $rule.pattern })
        if ($matches.Count -eq 0) { continue }

        [long] $measuredBytes = ($matches | Measure-Object -Property logicalBytes -Sum).Sum
        if ($measuredBytes -le 0) { continue }
        $recommendations.Add([pscustomobject]@{
            schemaVersion = 1
            kind = 'recommendation'
            id = $rule.id
            title = $rule.title
            summary = $rule.summary
            evidence = @($matches | ForEach-Object { "Measured $($_.logicalBytes) bytes at $($_.path)." })
            estimatedMinBytes = [long] [Math]::Floor($measuredBytes * $rule.minFactor)
            estimatedMaxBytes = $measuredBytes
            risk = $rule.risk
            reversibility = $rule.reversibility
            requiresElevation = $rule.elevation
            priority = $rule.priority
            actionable = $true
        })
    }

    if ($Diagnostics) {
        if ($Diagnostics.totalBytes -gt 0) {
            $freeRatio = [double] $Diagnostics.freeBytes / [double] $Diagnostics.totalBytes
            if ($freeRatio -lt 0.15) {
                $recommendations.Add([pscustomobject]@{
                    schemaVersion=1; kind='recommendation'; id='health.lowFreeSpace'; title='Restore free-space headroom'
                    summary='Keep at least 15% free, with 20% preferred for updates and temporary growth.'
                    evidence=@("Free-space ratio is $([Math]::Round($freeRatio * 100, 1))%.")
                    estimatedMinBytes=[long]0; estimatedMaxBytes=[long]0; risk='Low'; reversibility='Reversible'
                    requiresElevation=$false; priority=1; actionable=$false
                })
            }
        }

        if ($Diagnostics.pagefileBytes -ge 16GB) {
            $recommendations.Add([pscustomobject]@{
                schemaVersion=1; kind='recommendation'; id='system.pagefile'; title='Review unusually large pagefile'
                summary='Diagnose committed-memory pressure and crash-dump settings; keep system-managed sizing as the default.'
                evidence=@("Pagefile uses $($Diagnostics.pagefileBytes) bytes."); estimatedMinBytes=[long]0
                estimatedMaxBytes=[long]0; risk='High'; reversibility='BackupRecommended'; requiresElevation=$true
                priority=60; actionable=$false
            })
        }

        if ($Diagnostics.hiberfileBytes -gt 0) {
            $recommendations.Add([pscustomobject]@{
                schemaVersion=1; kind='recommendation'; id='power.hibernate'; title='Consider disabling hibernation'
                summary='Only disable hibernation if Hibernate and Fast Startup are not needed.'
                evidence=@("Hibernation file uses $($Diagnostics.hiberfileBytes) bytes."); estimatedMinBytes=[long]$Diagnostics.hiberfileBytes
                estimatedMaxBytes=[long]$Diagnostics.hiberfileBytes; risk='Medium'; reversibility='Reversible'; requiresElevation=$true
                priority=70; actionable=$true
            })
        }

        $diagnosticRules = @(
            [pscustomobject]@{ property='recycleBinBytes'; id='recycle.currentUser'; title='Empty the current user Recycle Bin'; summary='Preview Recycle Bin contents and confirm before permanently emptying them.'; priority=15; risk='Medium'; reversible='Irreversible'; elevation=$false; actionable=$true },
            [pscustomobject]@{ property='windowsComponentCleanupBytes'; id='windows.componentCleanup'; title='Clean superseded Windows components'; summary='Use the native DISM component-cleanup operation after confirmation.'; priority=50; risk='Medium'; reversible='Irreversible'; elevation=$true; actionable=$true },
            [pscustomobject]@{ property='dockerReclaimableBytes'; id='docker.reclaimable'; title='Review Docker reclaimable storage'; summary='Inspect image and volume ownership before running a Docker cleanup command.'; priority=80; risk='High'; reversible='Irreversible'; elevation=$false; actionable=$false },
            [pscustomobject]@{ property='wslVirtualDiskBytes'; id='wsl.storage'; title='Review WSL virtual-disk ownership'; summary='Clean data inside its owning distribution, then compact only after shutdown and backup.'; priority=90; risk='High'; reversible='BackupRecommended'; elevation=$true; actionable=$false }
        )
        foreach ($rule in $diagnosticRules) {
            [long] $bytes = $Diagnostics.($rule.property)
            if ($bytes -le 0) { continue }
            $recommendations.Add([pscustomobject]@{
                schemaVersion=1; kind='recommendation'; id=$rule.id; title=$rule.title; summary=$rule.summary
                evidence=@("Measured $bytes bytes from supplied $($rule.property) diagnostics.")
                estimatedMinBytes=[long]0; estimatedMaxBytes=$bytes; risk=$rule.risk; reversibility=$rule.reversible
                requiresElevation=$rule.elevation; priority=$rule.priority; actionable=$rule.actionable
            })
        }
    }

    return @($recommendations.ToArray() | Sort-Object priority, id)
}
