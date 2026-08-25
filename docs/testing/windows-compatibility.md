# Windows compatibility record

## Automated host

- Host build observed: Windows NT 10.0.26200.0 (Windows 11 branch), build 26200.9168.
- Architecture: x64.
- .NET SDK used: 8.0.424, locally installed for development.
- Automated .NET tests: 12 contract/schema, 17 WPF/client/integration/accessibility-markup, and 6 worker security tests passed.
- Automated PowerShell tests: 23 engine/CLI/signing tests passed, including Windows PowerShell 5.1 diagnostics-output compatibility.
- Packaged GUI E2E: 3 disposable-fixture workflows plus 1 screen-reader-semantics check passed from an interactive Windows 11 desktop, with TRX evidence under `artifacts\test-results`.

## Manual matrix

| Check | Windows 11 host | Windows 10 host |
|---|---|---|
| Non-admin GUI launch | Passed: packaged process started without elevation on build 26200.9168 | Requires separate host |
| Local folder scan | Passed: rebuilt packaged CLI measured 64 bytes / 1 file and emitted schema-v1 JSON | Requires separate host |
| Fixed drive scan | Passed: final packaged CLI completed a read-only E: root scan of 227,235 files / 54,369,251,583 logical bytes; four protected-path warnings were reported without failing the scan | Requires separate host |
| Removable drive scan | Requires removable media | Requires separate host/media |
| Cancellation and incomplete label | Passed in packaged GUI automation: immediate cancel produced partial read-only results and left Execute disabled | Requires separate host |
| UAC cancellation | Passed in separately enabled packaged automation: declining protected-diagnostics consent left the GUI running, reported no action, and recorded a local cancellation event | Requires separate host |
| Confirmed safe action | Passed in packaged GUI automation: scan, filter, JSON export, npm preview, explicit confirmation, worker handoff, post-action verification, audit evidence, and unrelated-file survival | Requires separate host |
| Offline/no connections | Passed: rebuilt packaged GUI process observed with 0 TCP connections | Requires separate host |
| MSI structure/extraction | Passed locally and in hosted Windows CI run 8: version/product/upgrade metadata, Start-menu definition, embedded runtime/legal files, ICE validation, checksum, and disposable administrative extraction | Requires separate host |
| MSI install/upgrade/uninstall | Passed unsigned lifecycle on Windows 11 build 26200.9168: 0.1.0 install, 0.1.1 major upgrade, Start-menu/uninstall registration, uninstall, and zero file/shortcut/registration residue | Requires signed elevated clean-host run |
| Keyboard-only application workflow | Passed in packaged automation: target, Analyze, tabs, filter, recommendation, preview, confirmation, Execute, and verified result used keyboard input | Requires separate host |
| Narrator announcements | Passed by project-owner manual walkthrough on build 26200.9168 | Requires separate host |
| 200% scaling | Passed by project-owner manual walkthrough on build 26200.9168 | Requires separate host |
| High-contrast presentation | Passed by project-owner manual walkthrough on build 26200.9168 | Requires separate host |
| Color contrast review | Passed by project-owner manual review on build 26200.9168; no remediation reported necessary | Requires separate host |

No unsupported manual result is marked as passed. Windows 10 release sign-off requires running this matrix on Windows 10 x64.

## External-host evidence collector

The portable package includes `validation\collect-windows-host-evidence.ps1`. Run it normally, without elevation, and optionally supply a local fixed/removable folder to scan:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\validation\collect-windows-host-evidence.ps1 `
  -ScanPath 'F:\PathSpace-Test' `
  -ReportPath '.\PathSpace-host-evidence.json'
```

The local JSON report identifies the package checksum manifest and records OS/build, architecture, administrator state, system DPI/scale, high-contrast state, all drive types, normal GUI launch, observed GUI TCP connection count, and the optional packaged CLI scan outcome. The collector conservatively leaves human checks unresolved because it cannot observe their result; the separate checklist above records the project owner's Windows 11 sign-off. The script performs no cleanup, requests no elevation, and uploads nothing.
