function Resolve-ActionDefinition {
    param([string] $ActionId, [hashtable] $Parameters)
    $catalog = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\catalog\actions.v1.psd1')
    if (-not $catalog.Actions.ContainsKey($ActionId)) { throw "Action '$ActionId' is not allow-listed by PathSpace." }
    $definition = $catalog.Actions[$ActionId]
    $targets = @()
    switch ($ActionId) {
        'temp.user' { $targets = @([pscustomobject]@{ targetId='temp.user.root'; path=[IO.Path]::GetFullPath($env:TEMP); requiresElevation=$false }) }
        'temp.windows' { $targets = @([pscustomobject]@{ targetId='temp.windows.root'; path=[IO.Path]::GetFullPath((Join-Path $env:windir 'Temp')); requiresElevation=$true }) }
        'cache.npm' { $targets = @([pscustomobject]@{ targetId='cache.npm.root'; path=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'npm-cache')); requiresElevation=$false }) }
        'recycle.currentUser' { $targets = @([pscustomobject]@{ targetId='recycle.currentUser'; path='shell:RecycleBinFolder'; requiresElevation=$false }) }
        'windows.componentCleanup' { $targets = @([pscustomobject]@{ targetId='windows.componentStore'; path='native:DISM/StartComponentCleanup'; requiresElevation=$true }) }
        'power.hibernate' { $targets = @([pscustomobject]@{ targetId='power.hibernate'; path='native:powercfg/hibernate'; requiresElevation=$true }) }
        'volume.optimize' {
            $letter = [string] $Parameters.DriveLetter
            if ($letter -notmatch '^[A-Za-z]$') { throw 'A single local drive letter is required for volume optimization.' }
            $targets = @([pscustomobject]@{ targetId="volume.$($letter.ToUpperInvariant())"; path="$($letter.ToUpperInvariant()):\"; requiresElevation=$true })
        }
    }
    foreach ($target in $targets) {
        if ($target.path -match '[*?%]' -or $target.path.StartsWith('\\')) { throw "Unsafe action target was rejected: '$($target.path)'." }
        if ($target.path -match '^[A-Za-z]:\\$' -and $ActionId -ne 'volume.optimize') { throw "Drive-root deletion targets are forbidden: '$($target.path)'." }
    }
    [pscustomobject]@{ Definition=$definition; Targets=$targets }
}
