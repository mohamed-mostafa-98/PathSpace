[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ActionId, [string]$DriveLetter)
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'engine\PathSpace.Engine\PathSpace.Engine.psd1'
Import-Module $modulePath -Force
$parameters = if ($DriveLetter) { @{ DriveLetter=$DriveLetter } } else { @{} }
Invoke-PathSpaceAction -ActionId $ActionId -Parameters $parameters -Confirmed | ConvertTo-Json -Depth 8 -Compress
