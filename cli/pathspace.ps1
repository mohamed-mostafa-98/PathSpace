[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('scan','recommend','diagnose','preview')]
    [string] $Command,

    [string] $LiteralPath,

    [string] $InputPath,

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
            Get-PathSpaceRecommendation -Snapshot $snapshot | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }
        }
        'diagnose' {
            Get-PathSpaceAppDiagnostic | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }
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
