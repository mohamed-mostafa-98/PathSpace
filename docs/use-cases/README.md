# PathSpace use cases

These use cases describe supported user goals and the safe application behavior expected for each flow.

## UC-01 — Understand why a drive is full

**Actor:** Windows user  
**Preconditions:** A local fixed or removable drive is mounted.  
**Flow:** Select the drive, start analysis, inspect categories, filter paths, review large files and warnings, then export a report if needed.  
**Outcome:** The user receives measured evidence without changing files.

## UC-02 — Analyze one folder

**Actor:** User or support engineer  
**Preconditions:** The folder is local and accessible.  
**Flow:** Browse to the folder, analyze, cancel if desired, and inspect complete or clearly labeled partial results.  
**Outcome:** Scope remains limited to the selected folder; junctions are reported but not followed.

## UC-03 — Perform a safe cleanup

**Actor:** User reclaiming space  
**Preconditions:** A complete scan and actionable recommendation exist.  
**Flow:** Select a recommendation, preview exact targets, review risk/reversibility/elevation, check explicit confirmation, execute, then review verification.  
**Outcome:** Only allow-listed targets are processed. Success is not claimed without verification evidence.

## UC-04 — Diagnose hidden Windows storage

**Actor:** Advanced user  
**Preconditions:** The normal scan cannot explain all used space.  
**Flow:** Open Advanced, run normal diagnostics, then optionally request administrator approval for protected read-only diagnostics. Review pagefile, hibernation, volumes, and protected-path evidence.  
**Outcome:** Protected system state is measured without running cleanup automatically.

## UC-05 — Diagnose Docker and WSL storage

**Actor:** Developer  
**Flow:** Review diagnostics that distinguish Docker Desktop/Windows context from native Docker inside WSL distributions. Inspect reclaimable images and named-volume warnings.  
**Outcome:** Ownership is clear; volumes and distributions are never auto-deleted.

## UC-06 — Review Notion local data

**Actor:** Notion user  
**Flow:** Measure Notion partitions, confirm pages are synchronized on another device or notion.so, close Notion, and use Notion's own reset-local-data control if appropriate.  
**Outcome:** PathSpace does not delete unknown Notion application data.

## UC-07 — Relocate Claude runtime data

**Actor:** Advanced user with limited C: space  
**Flow:** Prefer Windows Settings > Apps > Claude > Move. If unavailable, preview the guided relocation tool, copy to an NTFS destination, verify counts/bytes, retain rollback, create a junction, and test Claude. Use `-Rollback` if validation fails.  
**Outcome:** The original is recoverable until the user separately removes the retained backup.

## UC-08 — Review pagefile and hibernation

**Actor:** Advanced Windows user  
**Flow:** Review RAM, pagefile allocation/usage, automatic-management and crash-dump settings. Keep system-managed sizing by default. Disable hibernation only after accepting the Hibernate/Fast Startup impact.  
**Outcome:** System files are never deleted manually; elevated changes require confirmation.

## UC-09 — Optimize a volume

**Actor:** User maintaining a local drive  
**Flow:** Preview `volume.optimize` for a validated drive letter, confirm, approve elevation, and let Windows select retrim/defragment behavior according to media.  
**Outcome:** PathSpace delegates to the supported Windows `Optimize-Volume` operation.

## UC-10 — Export a support report

**Actor:** User or support engineer  
**Flow:** Complete a scan and export JSON, redacted JSON, or CSV. Use redacted JSON before sharing outside the device.  
**Outcome:** The report is written locally; PathSpace never uploads it.

## Out of scope

- Registry cleaning
- Network-share scanning
- Automatic deletion of Docker volumes or WSL distributions
- Automatic deletion of unknown application databases
- Custom SSD/HDD optimization algorithms
