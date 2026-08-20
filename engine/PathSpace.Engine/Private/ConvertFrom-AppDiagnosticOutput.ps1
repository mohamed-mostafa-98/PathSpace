function ConvertTo-PathSpaceBytes {
    param([string]$Value)
    if ($Value -match '^(?<n>[0-9.]+)(?<u>B|kB|KB|MB|GB|TB)$') {
        $power = @{B=0;KB=1;MB=2;GB=3;TB=4}[$Matches.u.ToUpperInvariant()]
        return [long]([double]$Matches.n * [Math]::Pow(1024,$power))
    }
    return [long]0
}
function ConvertFrom-DockerSystemDf {
    param([string]$Text)
    $rows = @{}
    foreach($line in ($Text -split '\r?\n')) {
        if($line -match '^(Images|Containers|Local Volumes|Build Cache)\s+\d+\s+\d+\s+(\S+)\s+(\S+)') { $rows[$Matches[1]]=[pscustomobject]@{size=ConvertTo-PathSpaceBytes $Matches[2]; reclaimable=ConvertTo-PathSpaceBytes $Matches[3]} }
    }
    [pscustomobject]@{ imageBytes=[long]$rows.Images.size; imageReclaimableBytes=[long]$rows.Images.reclaimable; volumeBytes=[long]$rows.'Local Volumes'.size; volumeReclaimableBytes=[long]$rows.'Local Volumes'.reclaimable; hasVolumes=([long]$rows.'Local Volumes'.size -gt 0) }
}
function ConvertFrom-WslList {
    param([string]$Text)
    foreach($line in (($Text -replace "`0",'') -split '\r?\n')) {
        if($line -match '^\s*\*?\s*(?<name>\S+)\s+(?<state>Running|Stopped)\s+(?<version>[12])\s*$' -and $Matches.name -ne 'NAME') { [pscustomobject]@{name=$Matches.name;state=$Matches.state;version=[int]$Matches.version} }
    }
}
