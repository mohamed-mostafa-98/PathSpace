# CLI reference

Entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\cli\pathspace.ps1 <command> [options]
```

All successful output is JSONL. Errors use a structured `scan.error` message and a nonzero exit code.

## Scan

```powershell
.\cli\pathspace.ps1 scan -LiteralPath 'C:\Users\Example'
```

Options:

- `-LiteralPath` — required absolute local drive or directory.
- `-LargeFileBytes` — optional large-file threshold; default is 1 GB.
- `-CancellationFile` — optional file whose presence requests a safe partial result.

The final message is a `scan.snapshot` with aggregates, large files, warnings, and completion state.

## Diagnose

```powershell
.\cli\pathspace.ps1 diagnose
.\cli\pathspace.ps1 diagnose -OutputPath 'C:\Temp\pathspace-diagnostics.jsonl'
```

Collects local Docker/WSL ownership, Notion, Claude, pagefile, hibernation, volume, and media evidence. Unavailable services produce an unavailable diagnostic rather than triggering cleanup.

## Recommend

```powershell
.\cli\pathspace.ps1 recommend `
  -InputPath 'C:\Temp\snapshot.json' `
  -DiagnosticsPath 'C:\Temp\diagnostics.jsonl'
```

Recommendations are deterministic and evidence-based. A recommendation is not permission to execute an action.

## Preview

```powershell
.\cli\pathspace.ps1 preview -ActionId temp.user
.\cli\pathspace.ps1 preview -ActionId volume.optimize -DriveLetter E
```

Preview resolves exact allow-listed targets and reports estimated bytes, risk, reversibility, and elevation requirements without changing state.

## PowerShell module

Advanced callers can import `engine\PathSpace.Engine\PathSpace.Engine.psd1` and use exported functions directly. Prefer the CLI when process isolation and JSONL contracts are useful.
