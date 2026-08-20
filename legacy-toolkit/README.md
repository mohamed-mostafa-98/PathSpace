# Windows Partition Analysis and Cleanup Guide

This toolkit documents the diagnostics and cleanup workflow used to recover space on a Windows C: partition. Run diagnostic scripts first, preserve backups, and never manually delete pagefiles, WSL/Docker virtual disks, or unknown application databases.

## Provenance and product boundary

These seven scripts were developed and manually validated during the storage-recovery session that inspired PathSpace. They are preserved for auditability and examples only. PathSpace production code does not dot-source or execute them. Sanitized command-output fixtures derived from the same session live under `tests/fixtures/legacy` for deterministic parser tests.

## Safety levels

- **Read-only:** `01-disk-status.ps1`, `02-find-hidden-space.ps1`, `03-analyze-users.ps1`, `04-analyze-programdata.ps1`, and `05-diagnose-pagefile.ps1`.
- **Controlled cleanup:** `06-safe-windows-cleanup.ps1` removes disposable temporary data, empties the Recycle Bin, and runs Windows component cleanup.
- **Application migration:** `07-move-claude-runtime-to-e.ps1` copies Claude runtime data to E:, retains a rollback copy, and creates a junction.
- **Destructive only after verification:** deleting a migration backup, Docker volumes, WSL distributions, or application data.

Run scripts from an **Administrator PowerShell** window:

```powershell
powershell -ExecutionPolicy Bypass -File ".\01-disk-status.ps1"
```

## Recommended workflow

1. Run `01-disk-status.ps1` for current free space and large root system files.
2. Run `02-find-hidden-space.ps1` for top-level folder totals and files larger than 1 GB.
3. Run `03-analyze-users.ps1` when `C:\Users` is large.
4. Run `04-analyze-programdata.ps1` when `C:\ProgramData` is large.
5. Run `05-diagnose-pagefile.ps1` before changing virtual-memory settings.
6. Run `06-safe-windows-cleanup.ps1` for conservative cleanup.
7. Re-run steps 1–4 and compare reports.

## Key interpretations

### Pagefile

`C:\pagefile.sys` is virtual memory. A registry value such as `C:\pagefile.sys 0 0` means Windows manages its size. Restart Windows after removing memory-heavy workloads; a system-managed pagefile may shrink automatically. Never delete it manually or disable it without checking installed RAM, current usage, peak usage, and committed memory.

### Hibernation

`C:\hiberfil.sys` supports Hibernate and usually Fast Startup. If Hibernate is not needed, recover its space with:

```powershell
powercfg /hibernate off
```

Restore it with:

```powershell
powercfg /hibernate on
```

### Docker Desktop and WSL

Docker Desktop data and a native Docker Engine inside Ubuntu are separate. Never delete a `.vhdx` until its owner is identified.

Inspect WSL distributions:

```powershell
wsl --list --verbose
```

Verify a native Docker Engine inside Ubuntu:

```powershell
wsl -d Ubuntu -- bash -lc 'command -v docker; sudo systemctl is-active docker; docker version; docker info --format "{{.DockerRootDir}}"'
```

Inspect Docker usage:

```powershell
wsl -d Ubuntu -- bash -lc 'docker system df -v'
```

Docker images can be downloaded again, but volumes may contain databases. Do not use `docker system prune --volumes` without inspecting volumes first.

### Browser data

Clear cached images/files through the browser UI. Avoid clearing passwords, autofill, cookies, or history unless intended. Chrome may store a multi-gigabyte downloadable model under `OptGuideOnDeviceModel`; deleting it is low risk, but Chrome may download it again.

### Notion

Large Notion `Partitions` storage may contain cache, IndexedDB, service-worker data, and offline content. Confirm pages are synchronized online, then prefer Notion's **Reset & Erase All Local Data** troubleshooting action over deleting folders manually.

### npm

Downloaded npm cache can be rebuilt:

```powershell
npm cache verify
npm cache clean --force
```

### ProgramData and Microsoft AppData

Do not delete these parent folders. Measure their child directories, then clean applications through their own settings or uninstallers. Authentication folders such as `TokenBroker`, `OneAuth`, `Identity`, `Credentials`, `Crypto`, and `Vault` should be preserved.

## Claude relocation

Prefer Windows **Settings > Apps > Claude > Move** when available. If packaged-app move fails, `07-move-claude-runtime-to-e.ps1` uses an NTFS junction. It checks E: capacity and filesystem, copies data with permissions, verifies the copy, retains a rollback directory on C:, and then creates the junction.

Test Claude before deleting the rollback directory. The expected junction is:

```text
C:\Users\DELL\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\vm_bundles
  -> E:\claude_data\vm_bundles
```

After successful testing, verify the junction target before deleting `vm_bundles.c-backup`.

## Healthy free-space target

Keep at least 15% of C: free; 20% or more gives Windows updates, pagefile growth, browsers, WSL, and developer tools more working room. Stop aggressive cleanup once the drive reaches a healthy range.

