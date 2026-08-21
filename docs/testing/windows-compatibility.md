# Windows compatibility record

## Automated host

- Host build observed: Windows NT 10.0.26200.0 (Windows 11 branch), build 26200.9168.
- Architecture: x64.
- .NET SDK used: 8.0.424, locally installed for development.
- Automated .NET tests: 2 contract, 14 WPF/client/integration/accessibility-markup, and 6 worker security tests passed.
- Automated PowerShell tests: 21 local-path, scan, cancellation, recommendation, action, Docker/WSL, and Claude relocation/rollback tests passed.

## Manual matrix

| Check | Windows 11 host | Windows 10 host |
|---|---|---|
| Non-admin GUI launch | Passed: packaged process started without elevation on build 26200.9168 | Requires separate host |
| Local folder scan | Passed: rebuilt packaged CLI measured 64 bytes / 1 file and emitted schema-v1 JSON | Requires separate host |
| Fixed drive scan | Passed: final packaged CLI completed a read-only E: root scan of 227,235 files / 54,369,251,583 logical bytes; four protected-path warnings were reported without failing the scan | Requires separate host |
| Removable drive scan | Requires removable media | Requires separate host/media |
| Cancellation and incomplete label | Covered by automated state tests | Requires separate host |
| UAC cancellation | Requires interactive confirmation | Requires separate host |
| Confirmed safe action | Passed: packaged worker removed only its generated 4 KB fixture; manifest validation and result handoff completed | Requires separate host |
| Offline/no connections | Passed: rebuilt packaged GUI process observed with 0 TCP connections | Requires separate host |

No unsupported manual result is marked as passed. Windows 10 release sign-off requires running this matrix on Windows 10 x64.
