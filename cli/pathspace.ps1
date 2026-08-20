[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('scan')]
    [string] $Command,

    [Parameter(Mandatory = $true)]
    [string] $LiteralPath,

    [long] $LargeFileBytes = 1GB,

    [string] $CancellationFile
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'engine\PathSpace.Engine\PathSpace.Engine.psd1'

try {
    Import-Module $modulePath -Force
    if ($Command -eq 'scan') {
        Invoke-PathSpaceScan -LiteralPath $LiteralPath -LargeFileBytes $LargeFileBytes -CancellationFile $CancellationFile
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
