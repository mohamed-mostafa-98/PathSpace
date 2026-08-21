# Build, test, and release

## Prerequisites

- Windows 10 or Windows 11 x64
- .NET 8 SDK
- Windows PowerShell 5.1
- Pester for engine tests
- PowerShell 7 for the packaged-worker verification helper

## Restore and test

```powershell
dotnet restore .\PathSpace.sln
dotnet test .\tests\PathSpace.Contracts.Tests\PathSpace.Contracts.Tests.csproj
dotnet test .\tests\PathSpace.Worker.Tests\PathSpace.Worker.Tests.csproj
dotnet test .\tests\PathSpace.App.Tests\PathSpace.App.Tests.csproj
Invoke-Pester -Script '.\tests\engine'
```

The current build passes 11 contract/schema, 6 worker-security, 17 application/accessibility, and 21 engine tests. Contract tests use JsonSchema.Net to validate representative serialized v1 messages against every schema and confirm invalid discriminators/unknown properties are rejected.

## Packaged GUI E2E tests

From an unlocked interactive Windows desktop, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-packaged-gui.ps1 -DotNetPath 'C:\path\to\dotnet.exe'
```

The script rebuilds the portable package and then enables two otherwise-skipped FlaUI tests. The complete workflow selects a disposable target, scans, filters categories, exports JSON through the Windows Save dialog, selects the npm-cache recommendation, previews exact targets, explicitly confirms, hands off to the packaged worker, verifies recovery, checks an unrelated file survived, and confirms a local audit event. The second workflow immediately cancels a large disposable scan and verifies partial results remain read-only.

Only the child process receives redirected `LOCALAPPDATA` and `PATHSPACE_AUDIT_DIRECTORY` values. Cleanup is therefore limited to the generated fixture. Results are written to `artifacts\test-results\PathSpace-packaged-gui.trx`. Do not run GUI automation in a locked or non-interactive desktop session.

## Build portable package

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-portable.ps1
```

If the SDK is installed privately and is not on `PATH`, supply its host explicitly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-portable.ps1 -DotNetPath 'C:\path\to\dotnet.exe'
```

Output:

```text
artifacts\PathSpace-win-x64
```

The folder includes the GUI, worker, engine, CLI, schemas, documentation hub, README, project status, contribution policy, changelog, MIT license, third-party notices, product icon, guided toolkit, and `SHA256SUMS.txt`.

## Package smoke test

```powershell
pwsh -NoProfile -File .\scripts\verify-portable-action.ps1
```

This creates and removes only its own disposable temporary fixture.

## Release checklist

- Confirm the Git worktree is clean.
- Run every test suite from the intended release commit.
- Rebuild the portable folder after the last documentation or source change.
- Verify every entry in `SHA256SUMS.txt`.
- Confirm executable product version `0.1.0`, informational version `0.1.0-private`, and the PathSpace application icon.
- Confirm `LICENSE` and `THIRD-PARTY-NOTICES.md` are present.
- Launch the packaged GUI as a normal user.
- Confirm no unexpected TCP connections.
- Scan a local folder and a fixed drive.
- Complete Windows 10, removable-media, UAC-cancellation, Narrator, keyboard, scaling, and high-contrast checks before a public release.

## Windows CI

`.github\workflows\windows-ci.yml` runs on pushes and pull requests targeting `master` or `main`, plus manual dispatch. It uses a least-privilege read-only repository token and a 30-minute timeout. The job restores .NET, treats build warnings as errors through repository properties, runs the .NET and Pester suites, validates local Markdown links and JSON contracts, builds the portable package, verifies every SHA-256 entry, and smoke-tests the packaged worker.

The Windows PowerShell step explicitly enables TLS 1.2, bootstraps the NuGet package provider, trusts PSGallery for the ephemeral runner, and pins Pester 4.10.1 to match the Windows PowerShell 5.1-compatible engine suite. No installed module is included in the product artifact.

CI retains test results and the portable package for 30 days. It does not sign binaries, access production credentials, upload runtime scan data, or exercise the interactive packaged GUI. Signing is a separate MOH-30 gate, and interactive GUI/accessibility runs require an unlocked Windows desktop.

Local equivalents for the standalone CI checks are:

```powershell
.\scripts\test-markdown-links.ps1
.\scripts\test-package-checksums.ps1
```
