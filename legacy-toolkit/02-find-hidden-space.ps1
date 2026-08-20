#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$ReportPath
)

$ErrorActionPreference = 'SilentlyContinue'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath 'hidden-c-drive-space-report.txt'
}

$root = 'C:\'
$rootInfo = [System.IO.DirectoryInfo]::new($root)
$totals = @{}
$largeFiles = [System.Collections.Generic.List[object]]::new()
$stack = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
$stack.Push($rootInfo)

while ($stack.Count -gt 0) {
    $directory = $stack.Pop()
    try {
        foreach ($file in $directory.EnumerateFiles()) {
            $relative = $file.FullName.Substring(3)
            $top = if ($relative.Contains('\')) { $relative.Split('\')[0] } else { '[C:\ files]' }
            if (-not $totals.ContainsKey($top)) { $totals[$top] = [int64]0 }
            $totals[$top] += $file.Length

            if ($file.Length -ge 1GB) {
                $largeFiles.Add([pscustomobject]@{
                    SizeGB = [math]::Round($file.Length / 1GB, 2)
                    Path   = $file.FullName
                })
            }
        }

        foreach ($child in $directory.EnumerateDirectories()) {
            if (($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                $stack.Push($child)
            }
        }
    } catch {
        continue
    }
}

$drive = Get-PSDrive -Name C
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("Scan time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("C: used: $([math]::Round($drive.Used / 1GB, 2)) GB")
$lines.Add("C: free: $([math]::Round($drive.Free / 1GB, 2)) GB")
$lines.Add('')
$lines.Add('TOP-LEVEL LOGICAL FILE SIZES')
$lines.Add('----------------------------')
foreach ($item in ($totals.GetEnumerator() | Sort-Object Value -Descending)) {
    $lines.Add(('{0,10:N2} GB  {1}' -f ($item.Value / 1GB), $item.Key))
}
$lines.Add('')
$lines.Add('FILES 1 GB OR LARGER')
$lines.Add('--------------------')
foreach ($item in ($largeFiles | Sort-Object SizeGB -Descending)) {
    $lines.Add(('{0,10:N2} GB  {1}' -f $item.SizeGB, $item.Path))
}

$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
$lines | ForEach-Object { Write-Host $_ }
Write-Host "Report saved to: $ReportPath"
Read-Host 'Press Enter to close this window'
