# PathSpace Design Specification

Date: 2026-08-20
Status: Approved
Product root: `E:\SIDE PROJECT\PartitionClearner`

## Understanding summary

- Build a Windows 10/11 graphical storage-analysis application backed by a reusable PowerShell/CLI engine.
- Serve general users through a guided simple mode and administrators through an advanced mode.
- Analyze fixed drives, removable drives, and individual local folders with progress and cancellation.
- Generate prioritized recommendations with estimated recoverable space and execute only explicitly confirmed actions.
- Run without elevation by default and request elevation only for protected scans or privileged actions.
- Support conservative cleanup plus guided workflows for Docker, WSL, Notion, Claude, pagefile, hibernation, and native `Optimize-Volume`.
- Work fully offline with no account, cloud synchronization, telemetry, or filesystem data leaving the computer.

## Assumptions

- Version 1 is private, maintained by one owner, but organized for a possible public release.
- Cleanup previews show exact targets, estimated recovery, risk, reversibility, and required privileges.
- Recoverable operations use the Recycle Bin or a rollback backup where practical.
- Irreversible actions require a stronger typed confirmation.
- Reparse points and junctions are reported but not followed by default.
- Windows-native capabilities and the standard library are preferred over new dependencies.
- Version 1 has a curated action catalog and no third-party plugin system.

## Non-goals

- Registry cleaning
- Custom disk defragmentation
- Antivirus or malware scanning
- Automatic application uninstalling
- Duplicate-file deletion
- Network-drive scanning
- Background monitoring or scheduled cleanup
- Cloud accounts, sync, or telemetry

## Architecture decision

Use a .NET 8 WPF GUI and a reusable Windows PowerShell-compatible module/CLI engine. The GUI invokes the engine out of process and consumes versioned JSON Lines. Privileged actions run through a separate short-lived elevated worker. This provides Windows 10/11 compatibility, keeps privilege boundaries visible, allows CLI use without the GUI, and avoids embedding a large PowerShell runtime inside the desktop process.

### Components

1. **PathSpace.App** — WPF desktop application. Owns navigation, view models, progress, cancellation, previews, confirmations, and report presentation.
2. **PathSpace.Engine** — PowerShell module and CLI entry point. Owns enumeration, classification, diagnostics, snapshots, and recommendation rules.
3. **PathSpace.Actions** — curated PowerShell action catalog. Each action declares risk, privilege, reversibility, preview logic, execution logic, and verification logic.
4. **PathSpace.Worker** — minimal .NET elevated launcher/validator. Accepts only known action identifiers and a validated local manifest.
5. **PathSpace.Contracts** — JSON schemas and .NET data-transfer records shared conceptually between GUI and engine.

### Data flow

```text
Target selection
  -> engine scan
  -> JSONL progress and versioned snapshot
  -> recommendation rules
  -> GUI review and selection
  -> action preview manifest
  -> user confirmation
  -> standard or elevated worker
  -> verification scan
  -> before/after recovery report
```

## User experience

### Simple mode

1. Select a local drive, removable drive, or folder.
2. Start analysis and watch progress; cancellation remains available.
3. Review storage categories and prioritized recommendations.
4. Select actions and inspect an exact preview.
5. Confirm actions individually or as a reviewed batch.
6. See verified recovered space and any skipped/failed targets.

### Advanced mode

- Exact paths, allocated/logical sizes, file counts, and inaccessible-path counts
- Large-file table and extension/category breakdowns
- Reparse-point and hard-link caveats
- JSON and CSV export
- CLI command preview
- Pagefile, crash-dump, WSL, Docker, and volume-optimization diagnostics
- Detailed action and verification logs

### Recommendation levels

- **Safe:** disposable cache or temporary data that can be recreated.
- **Review:** application data or downloads that may matter to the user.
- **Advanced:** system settings, virtual disks, junctions, or privileged operations.
- **Irreversible:** cannot be automatically restored; requires typed confirmation.

No destructive action is preselected. Partial/cancelled scans are visibly incomplete and cannot enable automatic cleanup actions.

## Scanning engine

The engine accepts a normalized local path and emits JSON Lines so progress and results can stream without holding the complete tree in GUI memory.

### Rules

- Normalize and validate the target before enumeration.
- Reject network/UNC paths in version 1.
- Do not follow reparse points by default; report them separately.
- Continue after access-denied and transient file errors, recording structured warnings.
- Use 64-bit byte counters and invariant JSON serialization.
- Separate logical size from allocated-size estimates where Windows APIs permit.
- Avoid scanning the same file identity twice when hard-link information is available; otherwise label totals as logical estimates.
- Cancellation stops scheduling new enumeration and exits at safe checkpoints.

### Snapshot contract

Every snapshot includes schema version, target, start/end time, completion state, logical bytes, optional allocated bytes, file/directory counts, inaccessible counts, top-level aggregates, large files, reparse points, diagnostics, and warnings.

## Recommendation engine

Recommendations are pure rules over a completed snapshot plus optional platform diagnostics. A recommendation contains:

- Stable rule and action identifiers
- Title and plain-language reason
- Evidence paths and measured bytes
- Estimated recoverable-byte range
- Risk and reversibility
- Required privilege
- Preview availability
- Relevant caveats

Version 1 rules cover free-space health, temporary data, Recycle Bin, browser caches, npm cache, Notion partitions, Docker/WSL ownership and reclaimable data, Claude runtime relocation, pagefile sizing diagnostics, hibernation, Windows component cleanup, and `Optimize-Volume` analysis.

## Action safety and elevation

Actions are allow-listed in source control. The GUI cannot submit arbitrary commands. Before execution, each action produces a manifest containing action ID, normalized targets, snapshot ID, preview bytes, timestamp, nonce, and SHA-256 digest. The worker rejects expired, modified, unknown, network, root-wide, or unresolved targets.

Elevation occurs only after the user confirms a privileged action. The worker displays the normal Windows UAC prompt, performs the narrow action, writes a structured result, and exits.

Recoverable deletion uses the Recycle Bin when practical. Migration actions copy, verify, retain a rollback directory, create a junction, and require a successful application test before backup deletion. Irreversible Docker volume or WSL-distribution deletion is guided rather than automated in version 1.

## Curated action catalog

### Executable safe actions

- User and Windows temporary-file cleanup, skipping locked files
- Current-user Recycle Bin cleanup
- Browser cache guidance and selected known-cache cleanup
- npm cache verification/cleanup
- Windows component cleanup through DISM
- Hibernation enable/disable through `powercfg`
- Native `Optimize-Volume` based on media type

### Guided advanced workflows

- Docker images/build cache; volumes remain protected unless explicitly inspected
- WSL package/log cleanup, trim, backup, and optional VHD compaction
- Notion reset only after sync verification
- Claude runtime relocation with junction and rollback
- Pagefile diagnostics; Windows-managed sizing remains the default recommendation

## Error handling

- Errors are structured by operation, path, native code, severity, and recoverability.
- Access-denied paths do not fail a scan; they reduce completeness and trigger an elevation suggestion.
- A cleanup batch isolates actions: one failure does not silently skip verification for successful actions.
- The GUI always distinguishes failed, skipped, cancelled, and successful states.
- Logs remain local and redact secret values, but paths remain visible unless the user selects redacted export.

## Testing strategy

### Engine tests

- Temporary fixture trees covering empty folders, large files, access errors, reparse points, Unicode paths, deep paths, cancellation, and changing files
- JSON schema compatibility tests
- Recommendation-rule table tests
- Path normalization and network-path rejection tests

### Action tests

- Preview/execution parity
- Allow-list and manifest-tamper rejection
- Recycle/backup/rollback behavior
- Locked-file and partial-failure handling
- No destructive integration tests against real user directories

### GUI tests

- View-model tests for progress, cancellation, filtering, confirmation, and incomplete scans
- Manual accessibility pass: keyboard navigation, focus, contrast, scaling, and screen-reader labels
- Windows 10 and Windows 11 smoke tests

### Acceptance tests

- Scan a local drive, removable drive, and arbitrary local folder.
- Keep UI responsive and cancellation functional.
- Explain major usage categories and large files.
- Produce prioritized recommendations with evidence and estimated recovery.
- Preview and execute approved safe actions only.
- Elevate only for protected actions.
- Verify and report actual recovered bytes.
- Produce no network traffic or telemetry.

## Packaging and maintenance

Version 1 ships as a signed-ready portable x64 package first. An MSIX/installer is deferred until the private build proves stable. The repository contains build scripts, local documentation, schemas, tests, and the legacy diagnostic scripts as reference fixtures. No auto-updater is included.

## Delivery milestones

1. **Foundation and contracts** — repository, solution, schemas, CLI shell, fixtures.
2. **Analysis engine MVP** — generic path scan, progress, cancellation, reports.
3. **Recommendation engine** — health model, evidence, risk, estimates.
4. **WPF GUI MVP** — simple/advanced modes and report views.
5. **Safe action framework** — previews, confirmation, elevation, verification.
6. **Guided integrations** — Docker, WSL, Notion, Claude, pagefile, hibernation, Optimize-Volume.
7. **Quality and packaging** — Windows 10/11 testing, accessibility, documentation, portable release.

## Decision log

| Decision | Alternatives | Rationale |
|---|---|---|
| Product name: PathSpace | Partition Cleaner, DiskScope | Covers drives and arbitrary folders without implying indiscriminate deletion. |
| WPF on .NET 8 | WinUI 3, PowerShell-only WPF | Mature Win10/11 support, maintainability, and lower packaging complexity. |
| Out-of-process PowerShell engine | Embedded SDK | Better isolation, CLI reuse, simpler privilege boundary. |
| JSON Lines contracts | Console text, one large JSON result | Streaming progress, cancellation, stable machine-readable integration. |
| On-demand elevation | Entire app elevated | Least privilege and clearer user consent. |
| Curated actions | Version 1 plugin system | Smaller attack surface and less premature abstraction. |
| Portable package first | Immediate MSIX/installer | Fastest private validation path; installer deferred until needed. |
| Native Optimize-Volume | Custom defragmenter | Correct SSD/HDD behavior without reinventing Windows functionality. |
| No registry cleaner | Registry deletion | Negligible storage benefit and disproportionate system risk. |

