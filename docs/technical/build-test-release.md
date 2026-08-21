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

The verified merged build passes 2 contract, 6 worker-security, 14 application/accessibility, and 21 engine tests.

## Build portable package

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-portable.ps1
```

Output:

```text
artifacts\PathSpace-win-x64
```

The folder includes the GUI, worker, engine, CLI, schemas, documentation hub, README, project status, contribution policy, changelog, guided toolkit, and `SHA256SUMS.txt`.

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
- Launch the packaged GUI as a normal user.
- Confirm no unexpected TCP connections.
- Scan a local folder and a fixed drive.
- Complete Windows 10, removable-media, UAC-cancellation, Narrator, keyboard, scaling, and high-contrast checks before a public release.
