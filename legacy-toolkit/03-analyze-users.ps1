#Requires -RunAsAdministrator
[CmdletBinding()]
param([string]$ReportPath)

$ErrorActionPreference = 'SilentlyContinue'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'users-space-report.txt'
}

function Measure-Tree {
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [int64]0
    $files = [int64]0
    $stack = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
    $stack.Push([System.IO.DirectoryInfo]::new($Path))
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        try {
            foreach ($file in $dir.EnumerateFiles()) {
                $bytes += $file.Length
                $files++
            }
            foreach ($child in $dir.EnumerateDirectories()) {
                if (($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                    $stack.Push($child)
                }
            }
        } catch { continue }
    }
    [pscustomobject]@{ Path=$Path; Bytes=$bytes; Files=$files }
}

$profile = 'C:\Users\DELL'
$sections = @(
    $profile,
    "$profile\AppData\Local",
    "$profile\AppData\Roaming",
    "$profile\Documents",
    "$profile\Downloads"
)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("Scan time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
foreach ($section in $sections) {
    if (-not (Test-Path -LiteralPath $section)) { continue }
    $lines.Add('')
    $lines.Add("CHILDREN OF $section")
    $lines.Add(('-' * [math]::Min(100, 12 + $section.Length)))
    $results = foreach ($child in (Get-ChildItem -LiteralPath $section -Force -Directory)) {
        if (($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
            Measure-Tree -Path $child.FullName
        }
    }
    foreach ($item in ($results | Sort-Object Bytes -Descending | Select-Object -First 30)) {
        $lines.Add(('{0,10:N2} GB  {1,10:N0} files  {2}' -f ($item.Bytes/1GB), $item.Files, $item.Path))
    }
}

$lines.Add('')
$lines.Add('FILES 250 MB OR LARGER UNDER C:\Users\DELL')
$lines.Add('--------------------------------------------')
$large = Get-ChildItem -LiteralPath $profile -Force -File -Recurse |
    Where-Object Length -ge 250MB |
    Sort-Object Length -Descending
foreach ($file in $large) {
    $lines.Add(('{0,10:N2} GB  {1}' -f ($file.Length/1GB), $file.FullName))
}

$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
$lines | ForEach-Object { Write-Host $_ }
Write-Host "Report saved to: $ReportPath"
Read-Host 'Press Enter to close this window'
