# Changelog

All notable PathSpace changes are recorded here. This project currently uses an `Unreleased` section until a formal versioning and installer strategy is completed.

## Unreleased

### Added

- Connected bounded `audit.event` v1 JSONL logging for scans, protected diagnostics, previews, and confirmed actions under `%LOCALAPPDATA%\PathSpace\Audit`, without raw target paths.
- Audit-file permission or I/O failures are non-fatal to the primary application workflow.
- Strict Draft 2020-12 schemas for every emitted v1 scan, recommendation, diagnostic, preview, manifest, result, and audit message family, plus serialized-contract validation tests.
- Version `0.1.0-private` product/assembly metadata, original PathSpace PNG/ICO artwork, MIT license, and third-party notices.
- Opt-in packaged WPF E2E automation for complete scan/filter/export/preview/confirm/worker/verification and cancellation/read-only workflows, using disposable fixtures and TRX release evidence.
- Least-privilege Windows CI workflow for .NET/Pester tests, Markdown and schema validation, portable packaging, checksum verification, worker smoke testing, and 30-day evidence retention.
- Reusable local Markdown-link and package-checksum validation scripts matching hosted CI gates.
- Validator path defaults resolve inside the script body for Windows PowerShell 5.1 compatibility.
- Hosted Windows PowerShell CI now bootstraps NuGet/TLS and pins Pester 4.10.1 non-interactively on ephemeral runners.
- GitHub remote and hosted Windows CI activated; the first fully verified run retained passing test evidence and the checksummed portable package.
- Authenticode package signing, expected-publisher/timestamp verification, post-signing checksum generation, signing manifest, protected manual release workflow, and disposable tamper test.
- Certificate ownership, secret handling, renewal/revocation responsibilities, release ordering, and clean-host signing gate documentation.
- Pinned WiX 5 per-machine MSI with self-contained .NET 8 desktop runtime, stable major-upgrade identity, Start-menu registration, portable fallback, and clean-host lifecycle harness.
- MSI metadata, embedded-runtime, shortcut, and disposable administrative-extraction verification in local and hosted Windows build flows.
- Embedded .NET runtime license and third-party notice files in the self-contained installer payload.
- Packaged keyboard-only GUI automation covering scan, tab navigation, filtering, recommendation preview, explicit confirmation, execution, and verified recovery.
- Windows CI now restores the default PowerShell Gallery registration when a hosted runner image omits it.
- Repository-wide documentation Definition of Done in `AGENTS.md`, `CONTRIBUTING.md`, and the documentation policy.
- Linear milestones M8 Engineering Completeness and M9 Public Release Readiness.
- Linear issues MOH-25 through MOH-32 covering audit logging, schemas, GUI E2E testing, legal/product identity, CI, signing, installer/runtime delivery, and documentation governance.
- Technical documentation and user use-case library.

### Changed

- Scan snapshots now retain their engine-issued `scanId` in the shared .NET contract.
- Portable packaging now includes the license, third-party notices, and product artwork.
- Portable builds accept an explicit `-DotNetPath` for private SDK installations.
- Stable UI Automation identifiers were added to visible workflow controls; managed tests may redirect audit files with an absolute local `PATHSPACE_AUDIT_DIRECTORY`.
- Root README and project status now link delivered behavior, documentation, and outstanding public-release work.
- Portable packaging now includes project status, contribution policy, and changelog so all packaged README links resolve.
- Release signing now covers PathSpace-owned binaries, packaged PowerShell, and the MSI container while preserving vendor signatures on the embedded Microsoft runtime.

### Verified

- Documentation link validation and checksummed portable-package rebuild after documentation updates.
- Hosted Windows CI run 5 passed the complete quality, portable-package, self-contained MSI, ICE/extraction, checksum, smoke-test, and three-artifact upload pipeline for commit `9b30825`.
