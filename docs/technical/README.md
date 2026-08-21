# Technical documentation

PathSpace is a Windows storage-analysis and guided-cleanup product built around a reusable PowerShell engine and a .NET 8 WPF application.

## Contents

- [Architecture](architecture.md)
- [CLI reference](cli-reference.md)
- [Security and cleanup safety](security-and-safety.md)
- [Build, test, and release](build-test-release.md)
- [Documentation maintenance policy](documentation-policy.md)

## Technology stack

- .NET 8 and WPF for the graphical application
- C# contracts shared by the application and worker
- Windows PowerShell 5.1-compatible analysis and action engine
- A narrow worker process for confirmed actions and elevation
- JSON/JSONL versioned messages and JSON Schema definitions
- xUnit and Pester automated tests

## Repository map

| Path | Responsibility |
|---|---|
| `src/PathSpace.App` | WPF UI, process client, exports, action coordination |
| `src/PathSpace.Contracts` | Versioned scan, recommendation, diagnostic, and action contracts |
| `src/PathSpace.Worker` | Strict manifest validation and narrow action dispatch |
| `engine/PathSpace.Engine` | Scanner, recommendations, diagnostics, previews, and allow-listed actions |
| `cli` | Scriptable JSONL entry points used by the UI and operators |
| `schemas` | Machine-readable contract schemas |
| `assets` | Original PathSpace icon artwork and Windows executable icon |
| `tests` | xUnit, Pester, fixtures, security, and integration tests |
| `legacy-toolkit` | Reviewed standalone guidance and migration utilities |
| `scripts` | Portable build and package verification scripts |
