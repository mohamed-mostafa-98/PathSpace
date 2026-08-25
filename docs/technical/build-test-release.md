# Build, test, and release

## Prerequisites

- Windows 10 or Windows 11 x64
- .NET 8 SDK
- Windows PowerShell 5.1
- Pester for engine tests
- PowerShell 7 for the packaged-worker verification helper
- Internet access during development/CI only to restore the pinned WiX 5.0.2 build tool; the produced installer and application remain offline

## Restore and test

```powershell
dotnet restore .\PathSpace.sln
dotnet test .\tests\PathSpace.Contracts.Tests\PathSpace.Contracts.Tests.csproj
dotnet test .\tests\PathSpace.Worker.Tests\PathSpace.Worker.Tests.csproj
dotnet test .\tests\PathSpace.App.Tests\PathSpace.App.Tests.csproj
Invoke-Pester -Script @('.\tests\engine','.\tests\signing')
```

The current build passes 11 contract/schema, 6 worker-security, 17 application/accessibility, and 23 PowerShell tests: 22 engine/CLI tests plus one disposable Authenticode signing/tamper test. Contract tests use JsonSchema.Net to validate representative serialized v1 messages against every schema and confirm invalid discriminators/unknown properties are rejected.

## Packaged GUI E2E tests

From an unlocked interactive Windows desktop, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-packaged-gui.ps1 -DotNetPath 'C:\path\to\dotnet.exe'
```

The script rebuilds the portable package and then enables three otherwise-skipped FlaUI tests. The complete workflow selects a disposable target, scans, filters categories, exports JSON through the Windows Save dialog, selects the npm-cache recommendation, previews exact targets, explicitly confirms, hands off to the packaged worker, verifies recovery, checks an unrelated file survived, and confirms a local audit event. The second workflow immediately cancels a large disposable scan and verifies partial results remain read-only. The third uses keyboard input only for target entry, Analyze, tabs, filtering, recommendation selection, preview, explicit confirmation, Execute, and verified recovery.

Only the child process receives redirected `LOCALAPPDATA` and `PATHSPACE_AUDIT_DIRECTORY` values. Cleanup is therefore limited to the generated fixture. Results are written to `artifacts\test-results\PathSpace-packaged-gui.trx`. Do not run GUI automation in a locked or non-interactive desktop session.

To validate real UAC cancellation, set both `PATHSPACE_RUN_PACKAGED_E2E=1` and `PATHSPACE_RUN_UAC_CANCEL_E2E=1`, run only `Declining_protected_diagnostics_uac_leaves_the_app_running_and_records_cancellation`, and choose **No** at the consent prompt. This separate opt-in test verifies the application remains open, reports cancellation, and writes a local cancellation audit event. The standard suite never requests elevation.

This UAC-decline test passed on Windows 11 build 26200.9168 on 2026-08-25 with TRX evidence in `artifacts\test-results\PathSpace-uac-cancellation.trx`.

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

The folder includes the GUI, worker, engine, CLI, schemas, documentation hub, README, project status, contribution policy, changelog, MIT license, third-party notices, PNG/ICO product artwork, guided toolkit, and `SHA256SUMS.txt`.

## Package smoke test

```powershell
pwsh -NoProfile -File .\scripts\verify-portable-action.ps1
```

This creates and removes only its own disposable temporary fixture.

## Build and verify MSI

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-installer.ps1
```

The MSI contains a self-contained x64 application and worker, so end users do not need to install .NET separately. The build runs standard Windows Installer ICE validation; the verifier reads MSI metadata and performs an administrative extraction into a unique temporary directory without registering the product. See [Installer and runtime strategy](installer-and-runtime.md) for clean-host lifecycle validation.

## Release checklist

- Confirm the Git worktree is clean.
- Run every test suite from the intended release commit.
- Rebuild the portable folder after the last documentation or source change.
- Verify every entry in `SHA256SUMS.txt`.
- Confirm executable product version `0.1.0`, informational version `0.1.0-private`, and the PathSpace application icon.
- Confirm `LICENSE` and `THIRD-PARTY-NOTICES.md` are present.
- Build and structurally verify the self-contained MSI.
- Verify signed MSI install, major upgrade, and uninstall on clean Windows 10 and Windows 11 x64 hosts.
- Launch the packaged GUI as a normal user.
- Confirm no unexpected TCP connections.
- Scan a local folder and a fixed drive.
- Complete Windows 10, removable-media, UAC-cancellation, Narrator, keyboard, scaling, and high-contrast checks before a public release.

## Windows CI

`.github\workflows\windows-ci.yml` runs on pushes and pull requests targeting `master` or `main`, plus manual dispatch. It uses a least-privilege read-only repository token and a 40-minute timeout. The job restores .NET, treats build warnings as errors through repository properties, runs the .NET and Pester suites, validates local Markdown links and JSON contracts, builds the portable package, verifies every SHA-256 entry, smoke-tests the packaged worker, then builds and structurally extracts the self-contained MSI.

The Windows PowerShell step explicitly enables TLS 1.2, bootstraps the NuGet package provider, restores the default PSGallery registration when a runner image omits it, trusts that ephemeral registration, and pins Pester 4.10.1 to match the Windows PowerShell 5.1-compatible engine suite. No installed module is included in the product artifact.

CI retains test results, the unsigned portable package, and the unsigned MSI for 30 days. It does not access production credentials, upload runtime scan data, or exercise the interactive packaged GUI. `.github\workflows\windows-release.yml` is a separate manually dispatched, protected-environment path that signs the portable package and MSI payload, builds and signs the MSI container, and refuses both uploads unless publisher signatures, timestamps, post-signing checksums, worker smoke testing, and MSI extraction pass. Interactive GUI/accessibility and install/upgrade/uninstall runs still require suitable Windows hosts.

The installer-enabled pipeline completed successfully on 2026-08-25 for commit `42d1fcc` ([Windows CI run 8](https://github.com/mohamed-mostafa-98/PathSpace/actions/runs/32842599878)). Every quality, portable, MSI build, ICE/extraction, checksum, smoke, and upload step passed. The run retained `pathspace-test-results-8`, `PathSpace-win-x64-8`, and `PathSpace-installer-win-x64-8`. An unsigned 0.1.0 to 0.1.1 install/major-upgrade/uninstall lifecycle also passed locally on Windows 11 build 26200.9168; signed Windows 10/11 clean-host runs remain release gates.

Local equivalents for the standalone CI checks are:

```powershell
.\scripts\test-markdown-links.ps1
.\scripts\test-package-checksums.ps1
```
