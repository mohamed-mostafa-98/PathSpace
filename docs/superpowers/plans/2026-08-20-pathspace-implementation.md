# PathSpace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an offline Windows 10/11 GUI and reusable PowerShell CLI that analyzes local storage, recommends safe recovery actions, executes only confirmed allow-listed actions, and verifies recovered space.

**Architecture:** A .NET 8 WPF application consumes versioned JSON Lines from an out-of-process PowerShell engine. A separate short-lived worker validates allow-listed action manifests and elevates only when required.

**Tech Stack:** .NET 8, WPF, C# 12, Windows PowerShell 5.1-compatible modules, Pester 5, xUnit, System.Text.Json, native Windows tools.

**Spec:** `docs/superpowers/specs/2026-08-20-pathspace-design.md`

## Global Constraints

- Support Windows 10 and Windows 11 x64.
- Operate fully offline with no accounts, telemetry, or network requests.
- Start the GUI without administrator privileges and elevate only a confirmed privileged action.
- Reject UNC/network paths in version 1.
- Do not follow reparse points by default.
- Never preselect destructive actions.
- Use native Windows facilities before adding dependencies.
- Keep the PowerShell engine independently callable from the CLI.
- Preserve the existing diagnostic scripts under `legacy-toolkit/` as reference fixtures.

---

## Planned file structure

```text
PartitionClearner/
  PathSpace.sln
  Directory.Build.props
  README.md
  docs/superpowers/specs/2026-08-20-pathspace-design.md
  docs/superpowers/plans/2026-08-20-pathspace-implementation.md
  legacy-toolkit/*.ps1
  schemas/scan-message.v1.schema.json
  schemas/action-manifest.v1.schema.json
  src/PathSpace.Contracts/
    PathSpace.Contracts.csproj
    ScanContracts.cs
    RecommendationContracts.cs
    ActionContracts.cs
  src/PathSpace.App/
    PathSpace.App.csproj
    App.xaml
    MainWindow.xaml
    MainWindow.xaml.cs
    MainViewModel.cs
    EngineClient.cs
  src/PathSpace.Worker/
    PathSpace.Worker.csproj
    Program.cs
    ManifestValidator.cs
  engine/PathSpace.Engine/
    PathSpace.Engine.psd1
    PathSpace.Engine.psm1
    Public/Invoke-PathSpaceScan.ps1
    Public/Get-PathSpaceRecommendation.ps1
    Public/Get-PathSpaceActionPreview.ps1
    Public/Invoke-PathSpaceAction.ps1
    Private/Resolve-SafeLocalPath.ps1
    Private/Get-TreeAggregate.ps1
    Private/Write-JsonLine.ps1
    catalog/actions.v1.psd1
  cli/pathspace.ps1
  tests/PathSpace.Contracts.Tests/
  tests/PathSpace.App.Tests/
  tests/PathSpace.Worker.Tests/
  tests/engine/*.Tests.ps1
```

### Task 1: Repository foundation and versioned contracts

**Files:**
- Create: `PathSpace.sln`, `Directory.Build.props`, `README.md`
- Create: `src/PathSpace.Contracts/PathSpace.Contracts.csproj`
- Create: `src/PathSpace.Contracts/ScanContracts.cs`
- Create: `src/PathSpace.Contracts/RecommendationContracts.cs`
- Create: `src/PathSpace.Contracts/ActionContracts.cs`
- Create: `schemas/scan-message.v1.schema.json`
- Create: `schemas/action-manifest.v1.schema.json`
- Test: `tests/PathSpace.Contracts.Tests/ContractSerializationTests.cs`

**Interfaces:**
- Produces: `ScanMessage`, `ScanProgress`, `ScanSnapshot`, `StorageAggregate`, `Recommendation`, `ActionPreview`, `ActionManifest`, `ActionResult`.
- Contract discriminator: `kind`; schema version: `schemaVersion = 1`.

- [ ] **Step 1: Create the solution and projects**

```powershell
dotnet new sln -n PathSpace
dotnet new classlib -n PathSpace.Contracts -o src/PathSpace.Contracts -f net8.0
dotnet new xunit -n PathSpace.Contracts.Tests -o tests/PathSpace.Contracts.Tests -f net8.0
dotnet sln add src/PathSpace.Contracts/PathSpace.Contracts.csproj tests/PathSpace.Contracts.Tests/PathSpace.Contracts.Tests.csproj
dotnet add tests/PathSpace.Contracts.Tests reference src/PathSpace.Contracts/PathSpace.Contracts.csproj
```

- [ ] **Step 2: Write a failing serialization test**

```csharp
[Fact]
public void Snapshot_round_trips_with_schema_version()
{
    var source = new ScanSnapshot(1, "scan.snapshot", @"C:\\", true, 42, 1, 0, []);
    var json = JsonSerializer.Serialize(source);
    var result = JsonSerializer.Deserialize<ScanSnapshot>(json)!;
    Assert.Equal(1, result.SchemaVersion);
    Assert.Equal(42, result.LogicalBytes);
}
```

- [ ] **Step 3: Run the test and confirm it fails**

```powershell
dotnet test tests/PathSpace.Contracts.Tests/PathSpace.Contracts.Tests.csproj
```

Expected: compilation failure because `ScanSnapshot` is undefined.

- [ ] **Step 4: Implement immutable record contracts and schemas**

Define the listed records with explicit JSON property names and long byte counters. Schemas require `schemaVersion`, `kind`, and target/action identifiers; disallow additional properties in signed manifests.

- [ ] **Step 5: Run tests and commit**

```powershell
dotnet test
git add .
git commit -m "feat: establish PathSpace contracts"
```

### Task 2: Safe local-path validation and fixture tree

**Files:**
- Create: `engine/PathSpace.Engine/PathSpace.Engine.psd1`
- Create: `engine/PathSpace.Engine/PathSpace.Engine.psm1`
- Create: `engine/PathSpace.Engine/Private/Resolve-SafeLocalPath.ps1`
- Test: `tests/engine/Resolve-SafeLocalPath.Tests.ps1`

**Interfaces:**
- Produces: `Resolve-SafeLocalPath -LiteralPath <string>` returning normalized `System.IO.DirectoryInfo`.
- Rejects: missing paths, files when a directory is required, UNC paths, unsupported providers.

- [ ] **Step 1: Write failing Pester cases**

```powershell
Describe 'Resolve-SafeLocalPath' {
    It 'normalizes a local directory' {
        (Resolve-SafeLocalPath -LiteralPath $TestDrive).FullName | Should -Be ([IO.Path]::GetFullPath($TestDrive))
    }
    It 'rejects a UNC path' {
        { Resolve-SafeLocalPath -LiteralPath '\\server\share' } | Should -Throw '*network*'
    }
}
```

- [ ] **Step 2: Run the focused test and confirm failure**

```powershell
Invoke-Pester tests/engine/Resolve-SafeLocalPath.Tests.ps1 -Output Detailed
```

- [ ] **Step 3: Implement validation using `GetUnresolvedProviderPathFromPSPath` and `DirectoryInfo`**

The function must use literal paths, reject `PathType -IsNetworkPath`, call `GetFullPath`, and return a directory object without enumerating it.

- [ ] **Step 4: Run tests and commit**

```powershell
Invoke-Pester tests/engine/Resolve-SafeLocalPath.Tests.ps1
git add engine tests
git commit -m "feat: validate local scan targets"
```

### Task 3: Generic scanner with progress and cancellation

**Files:**
- Create: `engine/PathSpace.Engine/Private/Get-TreeAggregate.ps1`
- Create: `engine/PathSpace.Engine/Private/Write-JsonLine.ps1`
- Create: `engine/PathSpace.Engine/Public/Invoke-PathSpaceScan.ps1`
- Create: `cli/pathspace.ps1`
- Test: `tests/engine/Invoke-PathSpaceScan.Tests.ps1`

**Interfaces:**
- Produces: `Invoke-PathSpaceScan -LiteralPath <string> [-LargeFileBytes <long>] [-CancellationFile <string>]`.
- Emits: progress/warning/snapshot JSONL messages conforming to schema v1.

- [ ] **Step 1: Write fixture tests for totals, Unicode, and reparse-point exclusion**

```powershell
It 'counts files and does not follow a junction' {
    Set-Content "$TestDrive\a.bin" ([byte[]]::new(10)) -AsByteStream
    $result = Invoke-PathSpaceScan -LiteralPath $TestDrive | Select-Object -Last 1 | ConvertFrom-Json
    $result.fileCount | Should -Be 1
    $result.logicalBytes | Should -Be 10
}
```

- [ ] **Step 2: Run and confirm failure**

```powershell
Invoke-Pester tests/engine/Invoke-PathSpaceScan.Tests.ps1 -Output Detailed
```

- [ ] **Step 3: Implement iterative directory traversal**

Use a `Stack[DirectoryInfo]`, 64-bit counters, safe checkpoints, per-directory exception capture, and `FileAttributes.ReparsePoint` exclusion. Emit progress no more than four times per second.

- [ ] **Step 4: Add cancellation-file test and implementation**

Create the cancellation file during a fixture scan and assert the final snapshot has `complete = false` and `cancelled = true`.

- [ ] **Step 5: Run engine tests and commit**

```powershell
Invoke-Pester tests/engine -Output Detailed
git add engine cli tests
git commit -m "feat: scan local storage with progress"
```

### Task 4: Recommendation rules

**Files:**
- Create: `engine/PathSpace.Engine/Public/Get-PathSpaceRecommendation.ps1`
- Test: `tests/engine/Get-PathSpaceRecommendation.Tests.ps1`

**Interfaces:**
- Consumes: completed schema-v1 `ScanSnapshot` plus optional diagnostics.
- Produces: ordered `Recommendation[]` with stable IDs, evidence, estimated range, risk, reversibility, and privilege.

- [ ] **Step 1: Write table-driven failing tests**

```powershell
It 'recommends npm cache cleanup with measured evidence' {
    $snapshot = [pscustomobject]@{ complete=$true; aggregates=@(@{path="$env:LOCALAPPDATA\npm-cache";logicalBytes=4GB}) }
    $result = Get-PathSpaceRecommendation -Snapshot $snapshot
    ($result | Where-Object id -eq 'cache.npm').estimatedMaxBytes | Should -Be 4GB
}
```

- [ ] **Step 2: Implement pure rules and deterministic priority ordering**

Rules must not inspect or modify the filesystem. They operate only on supplied evidence and diagnostics.

- [ ] **Step 3: Add incomplete-scan rejection test**

Assert cleanup recommendations are omitted and an `analysis.incomplete` notice is returned.

- [ ] **Step 4: Run tests and commit**

```powershell
Invoke-Pester tests/engine/Get-PathSpaceRecommendation.Tests.ps1
git add engine tests
git commit -m "feat: generate evidence-based recommendations"
```

### Task 5: WPF shell and engine client

**Files:**
- Create: `src/PathSpace.App/PathSpace.App.csproj`
- Create: `src/PathSpace.App/App.xaml`
- Create: `src/PathSpace.App/MainWindow.xaml`
- Create: `src/PathSpace.App/MainWindow.xaml.cs`
- Create: `src/PathSpace.App/MainViewModel.cs`
- Create: `src/PathSpace.App/EngineClient.cs`
- Test: `tests/PathSpace.App.Tests/EngineClientTests.cs`
- Test: `tests/PathSpace.App.Tests/MainViewModelTests.cs`

**Interfaces:**
- Produces: `EngineClient.ScanAsync(string target, IProgress<ScanProgress>, CancellationToken)` returning `ScanSnapshot`.
- `MainViewModel` exposes target, scan command, cancel command, progress, state, and snapshot.

- [ ] **Step 1: Scaffold WPF and test projects**

```powershell
dotnet new wpf -n PathSpace.App -o src/PathSpace.App -f net8.0-windows
dotnet new xunit -n PathSpace.App.Tests -o tests/PathSpace.App.Tests -f net8.0
dotnet sln add src/PathSpace.App/PathSpace.App.csproj tests/PathSpace.App.Tests/PathSpace.App.Tests.csproj
dotnet add src/PathSpace.App reference src/PathSpace.Contracts
dotnet add tests/PathSpace.App.Tests reference src/PathSpace.App src/PathSpace.Contracts
```

- [ ] **Step 2: Write a failing JSONL parsing test**

Feed progress and snapshot lines through a fake process stream and assert progress is reported before the final snapshot.

- [ ] **Step 3: Implement `EngineClient` using `ProcessStartInfo`**

Use redirected standard output/error, asynchronous line reads, the CLI script path from application base directory, and a cancellation file. Do not invoke through shell text concatenation.

- [ ] **Step 4: Implement simple dashboard and state tests**

The window contains target selection, Analyze, Cancel, progress, free-space health, and results placeholders. Verify commands disable correctly while scanning.

- [ ] **Step 5: Build, test, and commit**

```powershell
dotnet test
dotnet build PathSpace.sln -c Release
git add src tests
git commit -m "feat: add responsive WPF scan shell"
```

### Task 6: Result views and advanced mode

**Files:**
- Modify: `src/PathSpace.App/MainWindow.xaml`
- Modify: `src/PathSpace.App/MainViewModel.cs`
- Create: `src/PathSpace.App/ResultViewModels.cs`
- Test: `tests/PathSpace.App.Tests/ResultViewModelTests.cs`

**Interfaces:**
- Consumes: `ScanSnapshot`, `Recommendation[]`.
- Produces: category tree, large-file rows, warning list, recommendation cards, and simple/advanced visibility state.

- [ ] **Step 1: Write failing sorting/filtering tests**

Assert categories and large files sort descending by bytes and simple mode hides raw diagnostics.

- [ ] **Step 2: Implement focused result view models**

Keep formatting out of contracts. Provide byte-format helpers in one file and expose accessible labels.

- [ ] **Step 3: Build category, recommendation, and advanced tabs**

Use standard WPF controls, virtualization for large tables, keyboard-accessible commands, and no third-party UI framework.

- [ ] **Step 4: Run tests and commit**

```powershell
dotnet test tests/PathSpace.App.Tests
git add src tests
git commit -m "feat: present scan results and recommendations"
```

### Task 7: Action catalog and preview parity

**Files:**
- Create: `engine/PathSpace.Engine/catalog/actions.v1.psd1`
- Create: `engine/PathSpace.Engine/Public/Get-PathSpaceActionPreview.ps1`
- Create: `engine/PathSpace.Engine/Public/Invoke-PathSpaceAction.ps1`
- Test: `tests/engine/PathSpaceActions.Tests.ps1`

**Interfaces:**
- Produces: preview and result objects sharing stable target identities.
- Catalog actions: `temp.user`, `temp.windows`, `recycle.currentUser`, `cache.npm`, `windows.componentCleanup`, `power.hibernate`, `volume.optimize`.

- [ ] **Step 1: Write failing allow-list and preview tests**

Assert an unknown action throws and that preview targets exactly equal execution targets in dry-run mode.

- [ ] **Step 2: Implement catalog lookup and normalized target resolution**

No action accepts an arbitrary command. Each action resolves from explicit parameters through its catalog handler.

- [ ] **Step 3: Implement safe handlers with dry-run support**

Locked files are skipped and reported. Root paths, unresolved variables, wildcards, network paths, and reparse targets are rejected.

- [ ] **Step 4: Run tests and commit**

```powershell
Invoke-Pester tests/engine/PathSpaceActions.Tests.ps1
git add engine tests
git commit -m "feat: add previewable safe action catalog"
```

### Task 8: Signed manifest and elevated worker

**Files:**
- Create: `src/PathSpace.Worker/PathSpace.Worker.csproj`
- Create: `src/PathSpace.Worker/Program.cs`
- Create: `src/PathSpace.Worker/ManifestValidator.cs`
- Test: `tests/PathSpace.Worker.Tests/ManifestValidatorTests.cs`

**Interfaces:**
- Produces: `ManifestValidator.Validate(ActionManifest manifest, ReadOnlySpan<byte> manifestBytes)`.
- Worker arguments: `--manifest <absolute-json-path> --result <absolute-json-path>`.

- [ ] **Step 1: Write failing tests for digest, expiry, nonce, action ID, and target scope**

Create valid and tampered fixtures. Assert the validator rejects changed bytes, manifests older than five minutes, unknown IDs, UNC paths, and drive roots for deletion actions.

- [ ] **Step 2: Implement validator and worker dispatch**

Compute SHA-256 over canonical manifest content, compare fixed-time, validate against the embedded catalog, invoke the PowerShell action by argument array, and write one `ActionResult`.

- [ ] **Step 3: Add GUI elevation launcher**

Use `ProcessStartInfo.Verb = "runas"` only after confirmation. Treat UAC cancellation as a normal cancelled result.

- [ ] **Step 4: Test and commit**

```powershell
dotnet test tests/PathSpace.Worker.Tests
git add src tests
git commit -m "feat: isolate and validate elevated actions"
```

### Task 9: Guided application-specific workflows

**Files:**
- Create: `engine/PathSpace.Engine/Public/Get-PathSpaceAppDiagnostic.ps1`
- Create: `engine/PathSpace.Engine/catalog/guides.v1.psd1`
- Test: `tests/engine/AppDiagnostics.Tests.ps1`
- Modify: `src/PathSpace.App/MainWindow.xaml`

**Interfaces:**
- Produces diagnostics for Docker Desktop/native WSL Docker ownership, WSL distributions, Notion partitions, Claude runtime/junction, pagefile, hibernation, and volume media type.
- Guided actions never directly delete Docker volumes, WSL distributions, or unknown application data.

- [ ] **Step 1: Write command-output parser tests using saved fixtures**

Fixtures cover `wsl --list --verbose`, `docker system df -v`, pagefile CIM output, and unavailable-command cases.

- [ ] **Step 2: Implement diagnostics with command argument arrays and timeouts**

Return `available = false` plus a reason when Docker, WSL, CIM, or elevation is unavailable.

- [ ] **Step 3: Add guided cards and copyable commands**

Cards explain ownership, risk, backup requirements, and next steps. Commands are generated from validated values, never free-form user text.

- [ ] **Step 4: Run tests and commit**

```powershell
Invoke-Pester tests/engine/AppDiagnostics.Tests.ps1
dotnet test tests/PathSpace.App.Tests
git add engine src tests
git commit -m "feat: guide advanced storage recovery"
```

### Task 10: Exports, verification, and local audit log

**Files:**
- Create: `src/PathSpace.App/ReportExporter.cs`
- Create: `src/PathSpace.App/ActionCoordinator.cs`
- Test: `tests/PathSpace.App.Tests/ReportExporterTests.cs`
- Test: `tests/PathSpace.App.Tests/ActionCoordinatorTests.cs`

**Interfaces:**
- `ReportExporter.ExportJson`, `ExportCsv`, and `ExportRedactedJson`.
- `ActionCoordinator.ExecuteAsync(ActionPreview, CancellationToken)` always requests a post-action verification snapshot.

- [ ] **Step 1: Write failing redaction and verification tests**

Assert redacted export replaces the profile prefix with `%USERPROFILE%` and that successful execution without a verification snapshot is reported as `unverified`, not successful.

- [ ] **Step 2: Implement JSON/CSV export and local log rotation**

Use `System.Text.Json`, RFC-4180 CSV escaping, and five local log files capped at 5 MB each.

- [ ] **Step 3: Implement before/after verification coordination**

Compare measured free bytes and target bytes, display both, and never claim the preview estimate as actual recovery.

- [ ] **Step 4: Run tests and commit**

```powershell
dotnet test tests/PathSpace.App.Tests
git add src tests
git commit -m "feat: verify and export recovery reports"
```

### Task 11: Accessibility, compatibility, and portable packaging

**Files:**
- Create: `scripts/build-portable.ps1`
- Create: `docs/testing/windows-compatibility.md`
- Create: `docs/testing/accessibility-checklist.md`
- Modify: `README.md`

**Interfaces:**
- Produces: `artifacts/PathSpace-win-x64/` containing GUI, worker, engine, schemas, and licenses.

- [ ] **Step 1: Add a release build script**

```powershell
dotnet publish src/PathSpace.App/PathSpace.App.csproj -c Release -r win-x64 --self-contained false -o artifacts/PathSpace-win-x64
dotnet publish src/PathSpace.Worker/PathSpace.Worker.csproj -c Release -r win-x64 --self-contained false -o artifacts/PathSpace-win-x64/worker
Copy-Item engine,schemas -Destination artifacts/PathSpace-win-x64 -Recurse
```

- [ ] **Step 2: Run automated verification**

```powershell
dotnet test PathSpace.sln -c Release
Invoke-Pester tests/engine -Output Detailed
powershell -ExecutionPolicy Bypass -File scripts/build-portable.ps1
```

- [ ] **Step 3: Complete manual Windows 10/11 and accessibility checks**

Record OS build, local/removable/folder scans, cancellation, non-admin launch, UAC cancellation, safe action, keyboard navigation, 200% scaling, screen-reader labels, and offline network observation.

- [ ] **Step 4: Verify the portable artifact and commit**

Launch from a clean directory, complete one read-only folder scan, export JSON, and confirm no network connection is created.

```powershell
git add scripts docs README.md
git commit -m "chore: package and verify PathSpace"
```

