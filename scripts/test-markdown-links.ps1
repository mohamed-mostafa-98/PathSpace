[CmdletBinding()]
param([string]$Root)
$ErrorActionPreference='Stop'
if(-not $Root){$Root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path}
$broken=New-Object 'System.Collections.Generic.List[string]'
Get-ChildItem -LiteralPath $Root -Recurse -Filter '*.md' -File |
    Where-Object FullName -NotLike '*\artifacts\*' |
    ForEach-Object {
        $file=$_
        $content=Get-Content -LiteralPath $file.FullName -Raw
        foreach($match in [regex]::Matches($content,'(?<!!)\[[^\]]+\]\(([^)]+)\)')){
            $target=$match.Groups[1].Value.Trim().Trim('<','>').Split('#')[0]
            if([string]::IsNullOrWhiteSpace($target) -or $target -match '^(https?://|mailto:)'){continue}
            $decoded=[uri]::UnescapeDataString($target)
            if(-not (Test-Path -LiteralPath (Join-Path $file.DirectoryName $decoded))){$broken.Add("$($file.FullName): $target")}
        }
    }
if($broken.Count){$broken|Write-Error;throw "$($broken.Count) broken local Markdown link(s) found."}
Write-Output 'Markdown links valid.'
