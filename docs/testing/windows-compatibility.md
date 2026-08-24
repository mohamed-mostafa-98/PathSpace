# Windows compatibility record

## Automated host

- Host build observed: Windows NT 10.0.26200.0 (Windows 11 branch), build 26200.9168.
- Architecture: x64.
- .NET SDK used: 8.0.424, locally installed for development.
- Automated .NET tests: 11 contract/schema, 17 WPF/client/integration/accessibility-markup, and 6 worker security tests passed.
- Automated PowerShell tests: 21 local-path, scan, cancellation, recommendation, action, Docker/WSL, and Claude relocation/rollback tests passed.
- Packaged GUI E2E: 2 disposable-fixture workflows passed from an interactive Windows 11 desktop, with TRX evidence under `artifacts\test-results`.

## Manual matrix

| Check | Windows 11 host | Windows 10 host |
|---|---|---|
| Non-admin GUI launch | Passed: packaged process started without elevation on build 26200.9168 | Requires separate host |
| Local folder scan | Passed: rebuilt packaged CLI measured 64 bytes / 1 file and emitted schema-v1 JSON | Requires separate host |
| Fixed drive scan | Passed: final packaged CLI completed a read-only E: root scan of 227,235 files / 54,369,251,583 logical bytes; four protected-path warnings were reported without failing the scan | Requires separate host |
| Removable drive scan | Requires removable media | Requires separate host/media |
| Cancellation and incomplete label | Passed in packaged GUI automation: immediate cancel produced partial read-only results and left Execute disabled | Requires separate host |
| UAC cancellation | Requires interactive confirmation | Requires separate host |
| Confirmed safe action | Passed in packaged GUI automation: scan, filter, JSON export, npm preview, explicit confirmation, worker handoff, post-action verification, audit evidence, and unrelated-file survival | Requires separate host |
| Offline/no connections | Passed: rebuilt packaged GUI process observed with 0 TCP connections | Requires separate host |
| MSI structure/extraction | Passed: version/product/upgrade metadata, Start-menu definition, embedded runtime, and disposable administrative extraction | Requires separate host |
| Signed MSI install/upgrade/uninstall | Requires elevated clean-host lifecycle run with two signed versions | Requires elevated clean host |

No unsupported manual result is marked as passed. Windows 10 release sign-off requires running this matrix on Windows 10 x64.
