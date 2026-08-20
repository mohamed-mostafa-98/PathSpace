function Write-JsonLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object] $InputObject
    )

    process {
        $InputObject | ConvertTo-Json -Depth 10 -Compress
    }
}
