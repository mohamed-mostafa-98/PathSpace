[CmdletBinding()]
param([string]$ArtifactPath)
$ErrorActionPreference='Stop'
if(-not $ArtifactPath){$ArtifactPath=Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'artifacts\PathSpace-win-x64'}
$checksumPath=Join-Path $ArtifactPath 'SHA256SUMS.txt'
if(-not (Test-Path -LiteralPath $checksumPath)){throw "Checksum manifest not found: $checksumPath"}
$checked=0
$failures=New-Object 'System.Collections.Generic.List[string]'
foreach($line in Get-Content -LiteralPath $checksumPath){
    if($line -notmatch '^([A-Fa-f0-9]{64})  (.+)$'){throw "Invalid checksum line: $line"}
    $file=Join-Path $ArtifactPath $Matches[2]
    if(-not (Test-Path -LiteralPath $file)){$failures.Add("Missing: $($Matches[2])");continue}
    $actual=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    if($actual -ne $Matches[1]){$failures.Add("Mismatch: $($Matches[2])")}
    $checked++
}
if($failures.Count){$failures|Write-Error;throw "$($failures.Count) package checksum failure(s)."}
Write-Output "Verified $checked packaged file checksum(s)."
