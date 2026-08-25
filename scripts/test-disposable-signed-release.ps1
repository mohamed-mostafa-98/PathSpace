[CmdletBinding()]
param(
    [string]$DotNetPath,
    [string]$PortablePath,
    [string]$PayloadPath
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $PortablePath){$PortablePath=Join-Path $projectRoot 'artifacts\PathSpace-win-x64'}
if(-not $PayloadPath){$PayloadPath=Join-Path $projectRoot 'artifacts\installer-build\payload'}
$portableSource=(Resolve-Path -LiteralPath $PortablePath).Path
$payloadSource=(Resolve-Path -LiteralPath $PayloadPath).Path
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('pathspace-signed-release-'+[guid]::NewGuid().ToString('N'))
$portable=Join-Path $fixture 'portable'
$payload=Join-Path $fixture 'payload'
$installer=Join-Path $fixture 'installer'
$extract=Join-Path $fixture 'extracted'
$password=ConvertTo-SecureString ([guid]::NewGuid().ToString('N')) -AsPlainText -Force
$certificate=$null
try {
    Copy-Item -LiteralPath $portableSource -Destination $portable -Recurse
    Copy-Item -LiteralPath $payloadSource -Destination $payload -Recurse
    $certificate=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=PathSpace Disposable Full Release Test' -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddDays(1)
    $pfx=Join-Path $fixture 'disposable.pfx'
    Export-PfxCertificate -Cert $certificate -FilePath $pfx -Password $password | Out-Null

    foreach($artifact in @($portable,$payload)){
        & (Join-Path $PSScriptRoot 'sign-package.ps1') -ArtifactPath $artifact -CertificatePath $pfx -CertificatePassword $password -ExpectedThumbprint $certificate.Thumbprint -SkipTimestamp -AllowUntrusted
        & (Join-Path $PSScriptRoot 'test-package-checksums.ps1') -ArtifactPath $artifact
    }
    $pwsh=(Get-Command pwsh -ErrorAction Stop).Source
    & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'verify-portable-action.ps1') -ArtifactPath $portable | Out-Null
    if($LASTEXITCODE -ne 0){throw 'Signed worker smoke test failed.'}
    $msi=& (Join-Path $PSScriptRoot 'build-installer.ps1') -DotNetPath $DotNetPath -PayloadPath $payload -OutputPath $installer -SkipPayloadBuild | Select-Object -Last 1
    & (Join-Path $PSScriptRoot 'sign-package.ps1') -ArtifactPath $installer -CertificatePath $pfx -CertificatePassword $password -ExpectedThumbprint $certificate.Thumbprint -SkipTimestamp -AllowUntrusted
    & (Join-Path $PSScriptRoot 'test-package-checksums.ps1') -ArtifactPath $installer
    & (Join-Path $PSScriptRoot 'test-installer.ps1') -InstallerPath $msi

    New-Item -ItemType Directory -Path $extract | Out-Null
    $process=Start-Process msiexec.exe -ArgumentList @('/a',('"'+$msi+'"'),'/qn',('TARGETDIR="'+$extract+'"')) -Wait -PassThru
    if($process.ExitCode -ne 0){throw "Signed MSI extraction failed with exit code $($process.ExitCode)."}
    & (Join-Path $PSScriptRoot 'test-package-signatures.ps1') -ArtifactPath (Join-Path $extract 'PFiles64\PathSpace') -ExpectedThumbprint $certificate.Thumbprint -SkipTimestampRequirement -AllowUntrusted
    Write-Output 'Verified disposable signatures, checksums, worker execution, MSI structure, and signed MSI payload.'
} finally {
    if($certificate){Remove-Item -LiteralPath ('Cert:\CurrentUser\My\'+$certificate.Thumbprint) -Force -ErrorAction SilentlyContinue}
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
