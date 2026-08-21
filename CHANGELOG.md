# Changelog

All notable PathSpace changes are recorded here. This project currently uses an `Unreleased` section until a formal versioning and installer strategy is completed.

## Unreleased

### Added

- Connected bounded `audit.event` v1 JSONL logging for scans, protected diagnostics, previews, and confirmed actions under `%LOCALAPPDATA%\PathSpace\Audit`, without raw target paths.
- Audit-file permission or I/O failures are non-fatal to the primary application workflow.
- Strict Draft 2020-12 schemas for every emitted v1 scan, recommendation, diagnostic, preview, manifest, result, and audit message family, plus serialized-contract validation tests.
- Version `0.1.0-private` product/assembly metadata, original PathSpace PNG/ICO artwork, MIT license, and third-party notices.
- Repository-wide documentation Definition of Done in `AGENTS.md`, `CONTRIBUTING.md`, and the documentation policy.
- Linear milestones M8 Engineering Completeness and M9 Public Release Readiness.
- Linear issues MOH-25 through MOH-32 covering audit logging, schemas, GUI E2E testing, legal/product identity, CI, signing, installer/runtime delivery, and documentation governance.
- Technical documentation and user use-case library.

### Changed

- Scan snapshots now retain their engine-issued `scanId` in the shared .NET contract.
- Portable packaging now includes the license, third-party notices, and product artwork.
- Portable builds accept an explicit `-DotNetPath` for private SDK installations.
- Root README and project status now link delivered behavior, documentation, and outstanding public-release work.
- Portable packaging now includes project status, contribution policy, and changelog so all packaged README links resolve.

### Verified

- Documentation link validation and checksummed portable-package rebuild after documentation updates.
