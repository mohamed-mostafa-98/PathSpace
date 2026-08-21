# Authenticode signing and release integrity

## Trust model

The action-manifest SHA-256 digest and Authenticode publisher signatures solve different problems. The manifest digest detects mutation between preview and worker execution on one machine; it does not identify the publisher. Authenticode binds packaged code to a certificate identity and allows Windows to detect post-signing modification. `SHA256SUMS.txt` provides deterministic transport verification after signing.

A public release is trusted only when all three controls pass: expected publisher signature, trusted timestamp, and post-signing package checksum.

## Certificate ownership

The PathSpace release maintainer owns certificate enrollment, renewal, revocation response, and GitHub environment access. A publicly trusted code-signing certificate must be obtained from an appropriate certificate authority; a disposable self-signed certificate is accepted only by automated tamper tests and must never sign a release.

Prefer a CA-managed or hardware-backed private key. If a password-protected PFX must be used, export it only for the minimum required period, restrict access to the release maintainer, and rotate the GitHub secrets immediately after suspected disclosure. Never commit a PFX, password, base64 value, private-key file, or secret-bearing `.env` file.

## GitHub release-signing environment

Create a protected GitHub environment named `release-signing`, require maintainer approval, and configure:

| Name | Type | Meaning |
|---|---|---|
| `PATHSPACE_SIGNING_PFX_BASE64` | Environment secret | Base64 of the password-protected publisher PFX |
| `PATHSPACE_SIGNING_PFX_PASSWORD` | Environment secret | PFX password |
| `PATHSPACE_SIGNING_CERT_THUMBPRINT` | Environment secret | Expected publisher certificate SHA-1 thumbprint used for identity matching |
| `PATHSPACE_TIMESTAMP_URL` | Environment variable | CA-approved Authenticode/RFC 3161 timestamp endpoint |

The workflow writes the PFX only to `RUNNER_TEMP`, loads the private key ephemerally where supported, deletes the file in `finally`, and never prints secret values. Pull-request and normal Windows CI workflows do not receive signing secrets.

## Signing order

1. Build and test the exact release commit.
2. Build a fresh unsigned portable directory.
3. Validate certificate private key, code-signing EKU, validity window, and expected thumbprint.
4. SHA-256-sign every packaged `.exe`, `.dll`, `.ps1`, `.psm1`, and `.psd1` with the configured timestamp service.
5. Require every signature to be `Valid`, from the expected thumbprint, and timestamped.
6. Write `SIGNING-MANIFEST.json` without secrets.
7. Generate `SHA256SUMS.txt` after signing.
8. Verify every checksum and smoke-test the signed worker.
9. Upload only after all checks pass.

Any missing secret, certificate mismatch, expired/not-yet-valid certificate, missing code-signing purpose, failed timestamp, invalid signature, missing timestamp, checksum mismatch, or worker failure stops artifact publication.

## Local commands

Production signing requires a real certificate and timestamp service:

```powershell
$password = Read-Host 'PFX password' -AsSecureString
.\scripts\sign-package.ps1 `
  -CertificatePath 'C:\secure\PathSpace.pfx' `
  -CertificatePassword $password `
  -ExpectedThumbprint 'EXPECTED_CERTIFICATE_THUMBPRINT' `
  -TimestampServer 'https://ca-approved-timestamp.example'

.\scripts\test-package-signatures.ps1 -ExpectedThumbprint 'EXPECTED_CERTIFICATE_THUMBPRINT'
.\scripts\test-package-checksums.ps1
```

`-AllowUntrusted`, `-SkipTimestamp`, and `-SkipTimestampRequirement` exist solely for disposable self-signed automated tests. They are forbidden for release artifacts.

## Current gate

The signing implementation and disposable tamper test are delivered. MOH-30 remains incomplete until a real publisher certificate is configured and the resulting release artifact validates on a separate clean Windows host.
