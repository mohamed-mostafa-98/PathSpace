[CmdletBinding()]
param([string]$SitePath)
$ErrorActionPreference='Stop'
if(-not $SitePath){$SitePath=Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'site'}
$root=(Resolve-Path -LiteralPath $SitePath).Path
$index=Join-Path $root 'index.html'
$arabicIndex=Join-Path $root 'ar\index.html'
foreach($required in @($index,(Join-Path $root 'styles.css'),(Join-Path $root 'app.js'),(Join-Path $root 'assets\pathspace-icon.png'),
    $arabicIndex,
    (Join-Path $root 'assets\screenshots\pathspace-start.png'),(Join-Path $root 'assets\screenshots\pathspace-results.png'),
    (Join-Path $root 'assets\screenshots\pathspace-recommendations.png'))){
    if(-not (Test-Path -LiteralPath $required -PathType Leaf)){throw "Required site file is missing: $required"}
}
$html=Get-Content -LiteralPath $index -Raw
$arabicHtml=Get-Content -LiteralPath $arabicIndex -Raw
if($html -notmatch 'href="ar/"'){throw 'English page is missing its Arabic language link.'}
if($arabicHtml -notmatch '<html lang="ar" dir="rtl">'){throw 'Arabic page must declare Arabic and right-to-left direction.'}
if($arabicHtml -notmatch 'href="\.\./"'){throw 'Arabic page is missing its English language link.'}
foreach($id in @('downloads','how-it-works','docs','getting-started','interface','results-guide','safe-cleanup','cli','troubleshooting','release-notes','roadmap','license')){
    if($html -notmatch ('id="'+[regex]::Escape($id)+'"')){throw "Required site section is missing: $id"}
    if($arabicHtml -notmatch ('id="'+[regex]::Escape($id)+'"')){throw "Required Arabic site section is missing: $id"}
}
if($html -match 'github\.com/mohamed-mostafa-98/PathSpace/blob/'){throw 'Website documentation must be rendered on-page instead of redirecting to repository Markdown.'}
$references=[regex]::Matches($html,'(?:href|src)="([^"]+)"')|ForEach-Object{$_.Groups[1].Value}
foreach($reference in $references|Where-Object{$_ -notmatch '^(https?://|#|mailto:)'}){
    $target=Join-Path $root ($reference -replace '/','\')
    if(Test-Path -LiteralPath $target -PathType Container){$target=Join-Path $target 'index.html'}
    if(-not (Test-Path -LiteralPath $target -PathType Leaf)){throw "Broken local site reference: $reference"}
}
$arabicReferences=[regex]::Matches($arabicHtml,'(?:href|src)="([^"]+)"')|ForEach-Object{$_.Groups[1].Value}
foreach($reference in $arabicReferences|Where-Object{$_ -notmatch '^(https?://|#|mailto:)'}){
    $target=Join-Path (Split-Path $arabicIndex) ($reference -replace '/','\')
    if(Test-Path -LiteralPath $target -PathType Container){$target=Join-Path $target 'index.html'}
    if(-not (Test-Path -LiteralPath $target -PathType Leaf)){throw "Broken Arabic site reference: $reference"}
}
foreach($asset in @('PathSpace-0.1.0-win-x64.msi','PathSpace-0.1.0-private-portable-win-x64.zip','SHA256SUMS-release.txt')){
    if($html -notmatch [regex]::Escape("/releases/download/v0.1.0-private/$asset")){throw "Versioned release link is missing: $asset"}
}
Write-Output "Validated $($references.Count + $arabicReferences.Count) English/Arabic site references and required release links."
