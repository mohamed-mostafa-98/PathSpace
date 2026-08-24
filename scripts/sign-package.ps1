[CmdletBinding()]
param(
    [string]$ArtifactPath,
    [Parameter(Mandatory=$true)][string]$CertificatePath,
    [Parameter(Mandatory=$true)][Security.SecureString]$CertificatePassword,
    [Parameter(Mandatory=$true)][string]$ExpectedThumbprint,
    [string]$TimestampServer,
    [switch]$AllowUntrusted,
    [switch]$SkipTimestamp
)
$ErrorActionPreference='Stop'
if(-not $ArtifactPath){$ArtifactPath=Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'artifacts\PathSpace-win-x64'}
if(-not (Test-Path -LiteralPath $CertificatePath -PathType Leaf)){throw 'Signing certificate file was not found.'}
if(-not $SkipTimestamp -and [string]::IsNullOrWhiteSpace($TimestampServer)){throw 'A trusted RFC 3161/Authenticode timestamp server is required for release signing.'}
if($TimestampServer -and $TimestampServer -notmatch '^https?://'){throw 'Timestamp server must use HTTP or HTTPS.'}
$expected=$ExpectedThumbprint.Replace(' ','').ToUpperInvariant()
$certificate=New-Object Security.Cryptography.X509Certificates.X509Certificate2
$flags=[Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
if([Enum]::GetNames([Security.Cryptography.X509Certificates.X509KeyStorageFlags]) -contains 'EphemeralKeySet'){$flags=$flags -bor [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet}
try {
    $certificate.Import((Resolve-Path -LiteralPath $CertificatePath).Path,$CertificatePassword,$flags)
    if(-not $certificate.HasPrivateKey){throw 'Signing certificate does not contain a private key.'}
    if($certificate.Thumbprint.ToUpperInvariant() -ne $expected){throw 'Signing certificate thumbprint does not match the required publisher thumbprint.'}
    if([DateTime]::UtcNow -lt $certificate.NotBefore.ToUniversalTime() -or [DateTime]::UtcNow -gt $certificate.NotAfter.ToUniversalTime()){throw 'Signing certificate is outside its validity period.'}
    $codeSigningOid='1.3.6.1.5.5.7.3.3'
    $hasCodeSigning=@($certificate.Extensions | Where-Object {$_.Oid.Value -eq '2.5.29.37'} | ForEach-Object {$_.EnhancedKeyUsages | Where-Object Value -eq $codeSigningOid}).Count -gt 0
    if(-not $hasCodeSigning){throw 'Certificate is not authorized for code signing.'}
    Remove-Item -LiteralPath (Join-Path $ArtifactPath 'SHA256SUMS.txt') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $ArtifactPath 'SIGNING-MANIFEST.json') -Force -ErrorAction SilentlyContinue
    $files=@(Get-ChildItem -LiteralPath $ArtifactPath -Recurse -File | Where-Object {
        $_.Extension -In @('.ps1','.psm1','.psd1','.msi') -or
        ($_.Extension -In @('.exe','.dll') -and $_.Name -like 'PathSpace.*')
    } | Sort-Object FullName)
    if(-not $files.Count){throw 'No Authenticode-signable package files were found.'}
    foreach($file in $files){
        $parameters=@{LiteralPath=$file.FullName;Certificate=$certificate;HashAlgorithm='SHA256'}
        if(-not $SkipTimestamp){$parameters.TimestampServer=$TimestampServer}
        $signature=Set-AuthenticodeSignature @parameters
        $acceptable=$signature.Status -eq 'Valid' -or ($AllowUntrusted -and $signature.Status -eq 'UnknownError' -and $signature.SignerCertificate)
        if(-not $acceptable){throw "Signing failed for $($file.FullName): $($signature.Status) $($signature.StatusMessage)"}
    }
    & (Join-Path $PSScriptRoot 'test-package-signatures.ps1') -ArtifactPath $ArtifactPath -ExpectedThumbprint $expected -AllowUntrusted:$AllowUntrusted -SkipTimestampRequirement:$SkipTimestamp
    [pscustomobject]@{
        schemaVersion=1;kind='package.signing';signedAt=[DateTimeOffset]::UtcNow;publisher=$certificate.Subject
        thumbprint=$expected;certificateNotAfter=$certificate.NotAfter.ToUniversalTime().ToString('o')
        timestampServer=$(if($SkipTimestamp){$null}else{$TimestampServer});fileCount=$files.Count
        files=@($files|ForEach-Object {$_.FullName.Substring($ArtifactPath.Length+1)})
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $ArtifactPath 'SIGNING-MANIFEST.json') -Encoding UTF8
    & (Join-Path $PSScriptRoot 'new-package-checksums.ps1') -ArtifactPath $ArtifactPath
} finally {$certificate.Dispose()}
