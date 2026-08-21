[CmdletBinding()]
param([string]$ArtifactPath)
$ErrorActionPreference='Stop'
if(-not $ArtifactPath){$ArtifactPath=Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'artifacts\PathSpace-win-x64'}
if(-not (Test-Path -LiteralPath $ArtifactPath -PathType Container)){throw "Package directory not found: $ArtifactPath"}
$checksumPath=Join-Path $ArtifactPath 'SHA256SUMS.txt'
Remove-Item -LiteralPath $checksumPath -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $ArtifactPath -Recurse -File | Sort-Object FullName | Get-FileHash -Algorithm SHA256 | ForEach-Object {
    "$($_.Hash)  $($_.Path.Substring($ArtifactPath.Length+1))"
} | Set-Content -LiteralPath $checksumPath -Encoding UTF8
Write-Output $checksumPath
