[CmdletBinding()]
param([string]$SitePath)
$ErrorActionPreference='Stop'
if(-not $SitePath){$SitePath=Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'site'}
$root=(Resolve-Path -LiteralPath $SitePath).Path
$index=Join-Path $root 'index.html'
foreach($required in @($index,(Join-Path $root 'styles.css'),(Join-Path $root 'app.js'),(Join-Path $root 'assets\pathspace-icon.png'))){
    if(-not (Test-Path -LiteralPath $required -PathType Leaf)){throw "Required site file is missing: $required"}
}
$html=Get-Content -LiteralPath $index -Raw
foreach($id in @('downloads','how-it-works','docs','release-notes','roadmap')){
    if($html -notmatch ('id="'+[regex]::Escape($id)+'"')){throw "Required site section is missing: $id"}
}
$references=[regex]::Matches($html,'(?:href|src)="([^"]+)"')|ForEach-Object{$_.Groups[1].Value}
foreach($reference in $references|Where-Object{$_ -notmatch '^(https?://|#|mailto:)'}){
    $target=Join-Path $root ($reference -replace '/','\')
    if(-not (Test-Path -LiteralPath $target -PathType Leaf)){throw "Broken local site reference: $reference"}
}
foreach($asset in @('PathSpace-0.1.0-win-x64.msi','PathSpace-0.1.0-private-portable-win-x64.zip','SHA256SUMS-release.txt')){
    if($html -notmatch [regex]::Escape("/releases/download/v0.1.0-private/$asset")){throw "Versioned release link is missing: $asset"}
}
Write-Output "Validated $($references.Count) site references and required release links."
