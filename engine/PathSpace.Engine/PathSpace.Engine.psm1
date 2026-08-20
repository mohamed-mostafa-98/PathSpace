$privateScripts = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue
$publicScripts = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue

foreach ($script in @($privateScripts) + @($publicScripts)) {
    . $script.FullName
}

if ($publicScripts) {
    Export-ModuleMember -Function $publicScripts.BaseName
}
