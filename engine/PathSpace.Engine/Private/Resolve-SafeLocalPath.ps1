function Resolve-SafeLocalPath {
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    if ($LiteralPath.IndexOfAny([char[]]'*?') -ge 0) {
        throw "Wildcards are not allowed in a PathSpace target: '$LiteralPath'."
    }

    if ($LiteralPath.StartsWith('\\', [StringComparison]::Ordinal)) {
        throw "UNC and network paths are not supported by PathSpace: '$LiteralPath'."
    }

    try {
        $provider = $null
        $drive = $null
        $providerPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $LiteralPath,
            [ref] $provider,
            [ref] $drive)
    }
    catch {
        throw "The scan target uses an unsupported path or provider: '$LiteralPath'. $($_.Exception.Message)"
    }

    if ($null -eq $provider -or $provider.Name -ne 'FileSystem') {
        throw "Only local FileSystem provider paths are supported: '$LiteralPath'."
    }

    $fullPath = [IO.Path]::GetFullPath($providerPath)
    if ($fullPath.StartsWith('\\', [StringComparison]::Ordinal)) {
        throw "UNC and network paths are not supported by PathSpace: '$LiteralPath'."
    }

    $pathRoot = [IO.Path]::GetPathRoot($fullPath)
    if ([string]::IsNullOrWhiteSpace($pathRoot)) {
        throw "The PathSpace scan target does not have a local drive root: '$fullPath'."
    }

    $driveType = ([IO.DriveInfo]::new($pathRoot)).DriveType
    if ($driveType -eq [IO.DriveType]::Network) {
        throw "Mapped network drives are not supported by PathSpace: '$fullPath'."
    }

    if ($driveType -notin @([IO.DriveType]::Fixed, [IO.DriveType]::Removable, [IO.DriveType]::Ram)) {
        throw "Only fixed drives, removable drives, and their folders are supported: '$fullPath'."
    }

    if (-not [IO.Directory]::Exists($fullPath)) {
        if ([IO.File]::Exists($fullPath)) {
            throw "The PathSpace scan target must be a directory: '$fullPath'."
        }

        throw "The PathSpace scan target does not exist: '$fullPath'."
    }

    $directory = [IO.DirectoryInfo]::new($fullPath)
    if (($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "A reparse-point directory cannot be used as a PathSpace scan root: '$fullPath'."
    }

    return $directory
}
