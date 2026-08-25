[CmdletBinding()]
param(
    [string]$ArtifactPath,
    [string]$OutputPath
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $ArtifactPath){$ArtifactPath=Join-Path $projectRoot 'artifacts\PathSpace-win-x64'}
if(-not $OutputPath){$OutputPath=Join-Path $projectRoot 'site\assets\screenshots'}
$app=(Resolve-Path -LiteralPath (Join-Path $ArtifactPath 'PathSpace.App.exe')).Path
$fixture=Join-Path ([Environment]::GetFolderPath('CommonDocuments')) 'PathSpace-Screenshot-Fixture'
if(Test-Path $fixture){throw "Disposable screenshot fixture already exists: $fixture"}

Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PathSpaceScreenshotNative {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr handle, out Rect rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr handle);
}
'@

function Find-Control([System.Windows.Automation.AutomationElement]$Window,[string]$Id){
    $condition=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty,$Id)
    $control=$Window.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$condition)
    if(-not $control){throw "Automation control was not found: $Id"}
    $control
}

function Save-Window([Diagnostics.Process]$Process,[string]$Name){
    $Process.Refresh();$handle=$Process.MainWindowHandle
    if($handle -eq [IntPtr]::Zero){throw 'PathSpace window handle was not available.'}
    [PathSpaceScreenshotNative]::SetForegroundWindow($handle)|Out-Null
    Start-Sleep -Milliseconds 350
    $rect=New-Object PathSpaceScreenshotNative+Rect
    if(-not [PathSpaceScreenshotNative]::GetWindowRect($handle,[ref]$rect)){throw 'Unable to read PathSpace window bounds.'}
    $bitmap=New-Object Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try{$graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$bitmap.Size);$bitmap.Save((Join-Path $OutputPath $Name),[Drawing.Imaging.ImageFormat]::Png)}
    finally{$graphics.Dispose();$bitmap.Dispose()}
}

$oldLocalAppData=$env:LOCALAPPDATA
$oldAudit=$env:PATHSPACE_AUDIT_DIRECTORY
$process=$null
try{
    $npm=Join-Path $fixture 'npm-cache';$projects=Join-Path $fixture 'projects';$downloads=Join-Path $fixture 'downloads'
    New-Item -ItemType Directory -Path $npm,$projects,$downloads,$OutputPath -Force|Out-Null
    [IO.File]::WriteAllBytes((Join-Path $npm 'reclaimable-cache.bin'),([byte[]]::new(4MB)))
    [IO.File]::WriteAllBytes((Join-Path $projects 'project-data.bin'),([byte[]]::new(2MB)))
    [IO.File]::WriteAllBytes((Join-Path $downloads 'download.bin'),([byte[]]::new(1MB)))
    $env:LOCALAPPDATA=$fixture
    $env:PATHSPACE_AUDIT_DIRECTORY=Join-Path $fixture 'PathSpace\Audit'
    $process=Start-Process -FilePath $app -WorkingDirectory (Split-Path $app) -PassThru
    for($attempt=0;$attempt -lt 60 -and $process.MainWindowHandle -eq [IntPtr]::Zero;$attempt++){Start-Sleep -Milliseconds 250;$process.Refresh()}
    $windowCondition=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty,$process.Id)
    $window=[System.Windows.Automation.AutomationElement]::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Children,$windowCondition)
    if(-not $window){throw 'PathSpace automation window was not found.'}

    $target=Find-Control $window 'TargetPath'
    $valuePattern=$target.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    $valuePattern.SetValue($fixture)
    Save-Window $process 'pathspace-start.png'

    $analyze=Find-Control $window 'AnalyzeButton'
    $analyze.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    $status=Find-Control $window 'StatusText'
    for($attempt=0;$attempt -lt 240 -and $status.Current.Name -notlike 'Analysis complete:*';$attempt++){Start-Sleep -Milliseconds 250}
    if($status.Current.Name -notlike 'Analysis complete:*'){throw "Timed out waiting for scan completion: $($status.Current.Name)"}
    Save-Window $process 'pathspace-results.png'

    $recommendations=Find-Control $window 'RecommendationsTab'
    $recommendations.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
    Start-Sleep -Milliseconds 500
    Save-Window $process 'pathspace-recommendations.png'
    Write-Output $OutputPath
} finally {
    if($process -and -not $process.HasExited){$process.CloseMainWindow()|Out-Null;if(-not $process.WaitForExit(3000)){$process.Kill()}}
    $env:LOCALAPPDATA=$oldLocalAppData;$env:PATHSPACE_AUDIT_DIRECTORY=$oldAudit
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
