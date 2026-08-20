$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) '..\engine\PathSpace.Engine\PathSpace.Engine.psd1'
Import-Module (Resolve-Path $modulePath) -Force

Describe 'Get-PathSpaceRecommendation' {
    It 'recommends npm cache cleanup with measured evidence' {
        $snapshot = [pscustomobject]@{
            complete = $true
            aggregates = @([pscustomobject]@{ path = 'C:\Users\Example\AppData\Local\npm-cache'; logicalBytes = 4GB })
        }

        $result = Get-PathSpaceRecommendation -Snapshot $snapshot
        $recommendation = $result | Where-Object id -eq 'cache.npm'

        $recommendation.estimatedMaxBytes | Should Be 4GB
        $recommendation.risk | Should Be 'Low'
        $recommendation.requiresElevation | Should Be $false
    }

    It 'orders recommendations deterministically by priority then ID' {
        $snapshot = [pscustomobject]@{
            complete = $true
            aggregates = @(
                [pscustomobject]@{ path = 'C:\Users\Example\AppData\Local\Temp'; logicalBytes = 2GB },
                [pscustomobject]@{ path = 'C:\Users\Example\AppData\Local\npm-cache'; logicalBytes = 4GB }
            )
        }

        $result = @(Get-PathSpaceRecommendation -Snapshot $snapshot)
        $result[0].priority | Should BeLessThan ($result[-1].priority + 1)
        @($result.id) -join ',' | Should Be 'temp.user,cache.npm'
    }

    It 'returns an analysis notice only for an incomplete scan' {
        $snapshot = [pscustomobject]@{ complete = $false; aggregates = @() }

        $result = @(Get-PathSpaceRecommendation -Snapshot $snapshot)

        $result.Count | Should Be 1
        $result[0].id | Should Be 'analysis.incomplete'
        $result[0].actionable | Should Be $false
    }

    It 'uses supplied system diagnostics without inspecting the filesystem' {
        $snapshot = [pscustomobject]@{ complete = $true; aggregates = @() }
        $diagnostics = [pscustomobject]@{
            totalBytes = 100GB; freeBytes = 10GB; pagefileBytes = 39GB; hiberfileBytes = 6GB
            recycleBinBytes = 2GB; dockerReclaimableBytes = 15GB; wslVirtualDiskBytes = 23GB
            windowsComponentCleanupBytes = 3GB
        }

        $ids = @(Get-PathSpaceRecommendation -Snapshot $snapshot -Diagnostics $diagnostics).id

        ($ids -contains 'health.lowFreeSpace') | Should Be $true
        ($ids -contains 'recycle.currentUser') | Should Be $true
        ($ids -contains 'system.pagefile') | Should Be $true
        ($ids -contains 'power.hibernate') | Should Be $true
        ($ids -contains 'docker.reclaimable') | Should Be $true
        ($ids -contains 'wsl.storage') | Should Be $true
        ($ids -contains 'windows.componentCleanup') | Should Be $true
    }
}
