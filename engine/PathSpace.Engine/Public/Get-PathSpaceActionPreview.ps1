function Get-PathSpaceActionPreview {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$ActionId, [hashtable]$Parameters=@{})
    $resolved = Resolve-ActionDefinition -ActionId $ActionId -Parameters $Parameters
    [long]$estimatedBytes = 0
    foreach ($target in $resolved.Targets) {
        if ($ActionId -ne 'volume.optimize' -and -not $target.path.StartsWith('native:') -and -not $target.path.StartsWith('shell:') -and [IO.Directory]::Exists($target.path)) {
            $aggregate=Get-TreeAggregate -Root (Resolve-SafeLocalPath -LiteralPath $target.path) -LargeFileBytes ([long]::MaxValue)
            $estimatedBytes += $aggregate.logicalBytes
        }
    }
    [pscustomobject]@{ schemaVersion=1; kind='action.preview'; actionId=$ActionId; title=$resolved.Definition.Title; targets=$resolved.Targets; estimatedBytes=$estimatedBytes; risk=$resolved.Definition.Risk; reversibility=$resolved.Definition.Reversibility; requiresElevation=$resolved.Definition.RequiresElevation }
}
