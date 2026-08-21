$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Describe 'PathSpace Authenticode release pipeline' {
    It 'signs, verifies, checksums, and rejects a tampered disposable package' {
        $fixture=Join-Path $env:TEMP ('pathspace-signing-'+[guid]::NewGuid().ToString('N'))
        $artifact=Join-Path $fixture 'package'
        New-Item -ItemType Directory -Path $artifact -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $artifact 'fixture.ps1') -Value "Write-Output 'signed fixture'" -Encoding UTF8
        $certificate=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=PathSpace Disposable Signing Test' -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddDays(1)
        $password=ConvertTo-SecureString ([guid]::NewGuid().ToString('N')) -AsPlainText -Force
        $pfx=Join-Path $fixture 'fixture.pfx'
        try {
            Export-PfxCertificate -Cert $certificate -FilePath $pfx -Password $password | Out-Null
            { & (Join-Path $repoRoot 'scripts\sign-package.ps1') -ArtifactPath $artifact -CertificatePath $pfx -CertificatePassword $password -ExpectedThumbprint $certificate.Thumbprint -SkipTimestamp -AllowUntrusted } | Should Not Throw
            Test-Path -LiteralPath (Join-Path $artifact 'SIGNING-MANIFEST.json') | Should Be $true
            Test-Path -LiteralPath (Join-Path $artifact 'SHA256SUMS.txt') | Should Be $true
            Add-Content -LiteralPath (Join-Path $artifact 'fixture.ps1') -Value '# tampered'
            { & (Join-Path $repoRoot 'scripts\test-package-signatures.ps1') -ArtifactPath $artifact -ExpectedThumbprint $certificate.Thumbprint -SkipTimestampRequirement -AllowUntrusted } | Should Throw
        } finally {
            Remove-Item -LiteralPath ("Cert:\CurrentUser\My\"+$certificate.Thumbprint) -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
