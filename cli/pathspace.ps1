[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('scan','recommend','diagnose','preview')]
    [string] $Command,

    [string] $LiteralPath,

    [string] $InputPath,

    [string] $DiagnosticsPath,

    [string] $OutputPath,

    [string] $ActionId,

    [string] $DriveLetter,

    [long] $LargeFileBytes = 1GB,

    [string] $CancellationFile
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'engine\PathSpace.Engine\PathSpace.Engine.psd1'

try {
    Import-Module $modulePath -Force
    switch ($Command) {
        'scan' {
            if(-not $LiteralPath){throw '-LiteralPath is required for scan.'}
            Invoke-PathSpaceScan -LiteralPath $LiteralPath -LargeFileBytes $LargeFileBytes -CancellationFile $CancellationFile
        }
        'recommend' {
            if(-not $InputPath -or -not [IO.File]::Exists($InputPath)){throw 'A valid -InputPath snapshot JSON file is required.'}
            $snapshot=Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
            $diagnostics=$null
            if($DiagnosticsPath -and [IO.File]::Exists($DiagnosticsPath)){
                $items=@()
                foreach($line in @(Get-Content -LiteralPath $DiagnosticsPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })){
                    $parsed=$line|ConvertFrom-Json
                    $items += @($parsed)
                }
                $page=@($items|Where-Object id -eq 'pagefile'|Select-Object -First 1)
                $hiber=@($items|Where-Object id -eq 'hibernation'|Select-Object -First 1)
                $volume=@($items|Where-Object id -eq 'volume'|Select-Object -First 1)
                [long]$pageBytes=($page.data.pagefiles|Measure-Object -Property allocatedBytes -Sum).Sum
                [long]$hiberBytes=if($hiber.Count){$hiber[0].data.bytes}else{0}
                $systemDriveLetter=([string]$env:SystemDrive).TrimEnd(':')
                $systemVolume=@($volume.data.volumes|Where-Object DriveLetter -eq $systemDriveLetter|Select-Object -First 1)
                $diagnostics=[pscustomobject]@{
                    pagefileBytes=$pageBytes;hiberfileBytes=$hiberBytes
                    totalBytes=$(if($systemVolume.Count){[long]$systemVolume[0].Size}else{0})
                    freeBytes=$(if($systemVolume.Count){[long]$systemVolume[0].SizeRemaining}else{0})
                }
            }
            Get-PathSpaceRecommendation -Snapshot $snapshot -Diagnostics $diagnostics | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }
        }
        'diagnose' {
            $lines=@(Get-PathSpaceAppDiagnostic | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress })
            if($OutputPath){
                if(-not [IO.Path]::IsPathFullyQualified($OutputPath) -or $OutputPath.StartsWith('\\')){throw 'Diagnostics output must be an absolute local path.'}
                [IO.File]::WriteAllLines($OutputPath,[string[]]$lines,[Text.UTF8Encoding]::new($false))
            }else{$lines}
        }
        'preview' {
            if(-not $ActionId){throw '-ActionId is required for preview.'}
            $parameters=if($DriveLetter){@{DriveLetter=$DriveLetter}}else{@{}}
            Get-PathSpaceActionPreview -ActionId $ActionId -Parameters $parameters | ConvertTo-Json -Depth 10 -Compress
        }
    }
}
catch {
    [pscustomobject]@{
        schemaVersion = 1
        kind = 'scan.error'
        code = 'scan.failed'
        message = $_.Exception.Message
    } | ConvertTo-Json -Compress
    exit 1
}
