# Windows compatibility record

## Automated host

- Host build observed: Windows NT 10.0.26200.0 (Windows 11 branch), build 26200.9168.
- Architecture: x64.
- .NET SDK used: 8.0.424, locally installed for development.
- Automated .NET tests: contracts, WPF view models/client/export/coordinator, and worker security.
- Automated PowerShell tests: local-path boundaries, scanning, cancellation, recommendations, actions, Docker/WSL parsers.

## Manual matrix

| Check | Windows 11 host | Windows 10 host |
|---|---|---|
| Non-admin GUI launch | Passed: packaged process started without elevation on build 26200.9168 | Requires separate host |
| Local folder scan | Passed: packaged CLI measured 21 bytes / 1 file and emitted schema-v1 JSON | Requires separate host |
| Fixed drive scan | Not run against whole system drive | Requires separate host |
| Removable drive scan | Requires removable media | Requires separate host/media |
| Cancellation and incomplete label | Covered by automated state tests | Requires separate host |
| UAC cancellation | Requires interactive confirmation | Requires separate host |
| Confirmed safe action | Requires explicit disposable fixture | Requires separate host |
| Offline/no connections | Passed: packaged GUI process observed with 0 TCP connections | Requires separate host |

No unsupported manual result is marked as passed. Windows 10 release sign-off requires running this matrix on Windows 10 x64.
