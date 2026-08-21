# Architecture

## System overview

PathSpace separates read-only analysis from state-changing actions.

```text
User
  -> PathSpace.App (WPF, normally non-admin)
      -> cli/pathspace.ps1
          -> PathSpace.Engine (scan, diagnose, recommend, preview)
      -> explicit preview and confirmation
          -> PathSpace.Worker (normal or UAC-elevated)
              -> allow-listed engine action
      -> post-action verification scan
```

## Components

### WPF application

`PathSpace.App` owns target selection, progress, cancellation, result filtering, recommendations, exact-target previews, confirmation, exports, diagnostics, and outcome presentation. It does not run elevated by default.

### PowerShell engine and CLI

The engine accepts local fixed drives, removable drives, and individual local folders. It does not follow reparse points during scans. The CLI emits versioned JSONL so the same engine can serve the GUI and automation.

### Contracts

Contracts carry `schemaVersion` and `kind` fields. Strict Draft 2020-12 schemas cover scan progress/snapshots/errors, recommendations, application diagnostics, action previews, action manifests, action results, and local audit events. Contract tests validate serialized .NET payloads and reject incorrect discriminators or unknown properties where the contract is strict.

### Worker and actions

The worker receives a short-lived manifest containing an allow-listed action ID and exact target identities. It validates strict JSON shape, expiry, digest, local target scope, and action rules before dispatch. Unknown commands and arbitrary command strings are not accepted.

### Verification

The application requests a post-action scan where applicable. It distinguishes measured recovery from target removal and labels outcomes as unverified when verification evidence is unavailable.

## Data and privacy

- All analysis and reports remain local unless the user manually moves an exported file.
- There is no telemetry, account, cloud sync, analytics endpoint, or updater.
- Paths may contain private information; redacted JSON export replaces the user-profile prefix.
- Workflow audit events are written under `%LOCALAPPDATA%\PathSpace\Audit` as versioned JSON Lines. The active file is capped at 5 MiB and rotated across at most five files.
- Audit records contain workflow outcomes and numeric evidence but omit raw scan and action target paths. They never leave the computer automatically.
- Managed deployments and the disposable E2E harness may set `PATHSPACE_AUDIT_DIRECTORY` to an absolute non-UNC local directory; otherwise the default location is used.

## Platform scope

The product is designed for Windows 10/11 x64. The current portable package is framework-dependent and requires the .NET 8 Desktop Runtime. Windows-native integrations include WPF, PowerShell, DISM, `powercfg`, WSL/Docker diagnostics, and `Optimize-Volume`.
