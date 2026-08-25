[CmdletBinding()]
param(
    [string]$ProductRoot,
    [string]$ScanPath,
    [string]$ReportPath,
    [switch]$SkipAppLaunch
)
$ErrorActionPreference = 'Stop'

if (-not $ProductRoot) {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $ProductRoot = if (Test-Path (Join-Path $repositoryRoot 'PathSpace.App.exe')) { $repositoryRoot } else { Join-Path $repositoryRoot 'artifacts\PathSpace-win-x64' }
}
$ProductRoot = (Resolve-Path -LiteralPath $ProductRoot).Path
$appPath = Join-Path $ProductRoot 'PathSpace.App.exe'
$cliPath = Join-Path $ProductRoot 'cli\pathspace.ps1'
foreach ($required in @($appPath, $cliPath, (Join-Path $ProductRoot 'SHA256SUMS.txt'))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Portable package file was not found: $required" }
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$os = Get-CimInstance Win32_OperatingSystem
Add-Type -AssemblyName PresentationFramework
try {
    Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public static class PathSpaceDpi { [DllImport("user32.dll")] public static extern uint GetDpiForSystem(); }' -ErrorAction Stop
    $systemDpi = [PathSpaceDpi]::GetDpiForSystem()
} catch { $systemDpi = $null }

$drives = @([IO.DriveInfo]::GetDrives() | ForEach-Object {
    [pscustomobject]@{
        name = $_.Name
        type = $_.DriveType.ToString()
        ready = $_.IsReady
        format = if ($_.IsReady) { $_.DriveFormat } else { $null }
        totalBytes = if ($_.IsReady) { $_.TotalSize } else { $null }
        freeBytes = if ($_.IsReady) { $_.AvailableFreeSpace } else { $null }
    }
})

$application = $null
if (-not $SkipAppLaunch) {
    $process = Start-Process -FilePath $appPath -WorkingDirectory $ProductRoot -PassThru
    try {
        for ($attempt = 0; $attempt -lt 50 -and -not $process.HasExited; $attempt++) {
            $process.Refresh()
            if ($process.MainWindowHandle -ne 0) { break }
            Start-Sleep -Milliseconds 100
        }
        $tcpCount = $null
        if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
            $tcpCount = @(Get-NetTCPConnection -OwningProcess $process.Id -ErrorAction SilentlyContinue).Count
        }
        $application = [pscustomobject]@{
            launched = (-not $process.HasExited -and $process.MainWindowHandle -ne 0)
            launchedFromNonAdministratorHost = (-not $isAdministrator)
            tcpConnectionCount = $tcpCount
        }
    } finally {
        if (-not $process.HasExited) {
            $null = $process.CloseMainWindow()
            if (-not $process.WaitForExit(3000)) { $process.Kill() }
        }
        $process.Dispose()
    }
}

$scan = $null
if ($ScanPath) {
    $ScanPath = (Resolve-Path -LiteralPath $ScanPath).Path
    $messages = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cliPath scan -LiteralPath $ScanPath)
    if ($LASTEXITCODE -ne 0) { throw "Packaged CLI scan failed with exit code $LASTEXITCODE." }
    $snapshot = @($messages | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object kind -eq 'scan.snapshot')[-1]
    if (-not $snapshot) { throw 'Packaged CLI scan did not emit a scan.snapshot message.' }
    $scanDrive = New-Object IO.DriveInfo([IO.Path]::GetPathRoot($ScanPath))
    $scan = [pscustomobject]@{
        targetPath = $ScanPath
        driveType = $scanDrive.DriveType.ToString()
        complete = [bool]$snapshot.complete
        cancelled = [bool]$snapshot.cancelled
        logicalBytes = [long]$snapshot.logicalBytes
        fileCount = [long]$snapshot.fileCount
        warningCount = @($snapshot.warnings).Count
    }
}

if (-not $ReportPath) { $ReportPath = Join-Path (Get-Location) ("PathSpace-host-evidence-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$ReportPath = [IO.Path]::GetFullPath($ReportPath)
$report = [ordered]@{
    schemaVersion = 1
    kind = 'host.validation'
    collectedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    collectorNetworkAccess = $false
    telemetry = $false
    package = [ordered]@{
        root = $ProductRoot
        version = [Diagnostics.FileVersionInfo]::GetVersionInfo($appPath).ProductVersion
        checksumManifestSha256 = (Get-FileHash -LiteralPath (Join-Path $ProductRoot 'SHA256SUMS.txt') -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    host = [ordered]@{
        caption = $os.Caption
        version = $os.Version
        buildNumber = $os.BuildNumber
        architecture = $os.OSArchitecture
        powershell = $PSVersionTable.PSVersion.ToString()
        administrator = $isAdministrator
        systemDpi = $systemDpi
        scalePercent = if ($systemDpi) { [math]::Round($systemDpi / 96 * 100) } else { $null }
        highContrast = [System.Windows.SystemParameters]::HighContrast
    }
    drives = $drives
    application = $application
    scan = $scan
    manualChecksStillRequired = @('Narrator announcements', '200% scaling layout', 'high-contrast visual review', 'measured color contrast', 'signed installer lifecycle')
}
$parent = Split-Path -Parent $ReportPath
if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
[IO.File]::WriteAllText($ReportPath, ($report | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Output $ReportPath
