# PathSpace

PathSpace is an offline Windows 10/11 storage analyzer and guided cleanup application. It combines a .NET 8 WPF interface with a reusable PowerShell/CLI engine.

## Current status

The first portable implementation is in verification. It includes versioned contracts, an offline PowerShell analysis engine, deterministic recommendations, a responsive WPF shell, guarded actions, an elevated worker, guided diagnostics, and exports.

- [Design specification](docs/superpowers/specs/2026-08-20-pathspace-design.md)
- [Implementation plan](docs/superpowers/plans/2026-08-20-pathspace-implementation.md)
- [Linear project](https://linear.app/mohamed-mostafa/project/pathspace-04c36f87d38a)
- [Linear product brief](https://linear.app/mohamed-mostafa/document/pathspace-product-brief-and-delivery-map-1d643a7fda3b)

## Planned architecture

- `src/PathSpace.App` — .NET 8 WPF interface
- `src/PathSpace.Contracts` — versioned JSON contracts
- `src/PathSpace.Worker` — narrow elevated worker
- `engine/PathSpace.Engine` — reusable PowerShell module
- `cli/pathspace.ps1` — command-line entry point
- `schemas` — JSON schemas
- `tests` — .NET and Pester tests
- `legacy-toolkit` — diagnostic scripts developed before the product project

## Project constraints

- Windows 10 and Windows 11 x64
- Fully offline; no telemetry or accounts
- Local fixed/removable drives and local folders only
- Normal non-admin launch; elevation only for confirmed protected actions
- Preview, confirmation, recovery safeguards, and post-action verification
- No registry cleaner, custom defragmenter, network scanning, or v1 plugin framework

## Build and test

Install the .NET 8 SDK, then run:

```powershell
dotnet restore PathSpace.sln
dotnet build PathSpace.sln -c Release --no-restore
dotnet test PathSpace.sln -c Release --no-build
```

The PowerShell engine test command will become available with the analysis-engine milestone:

```powershell
Invoke-Pester tests/engine -Output Detailed
```

Build the portable x64 folder with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-portable.ps1
```

The output is `artifacts\PathSpace-win-x64`. PathSpace makes no network requests and does not include telemetry. Cleanup actions are never preselected and require preview plus explicit confirmation.

