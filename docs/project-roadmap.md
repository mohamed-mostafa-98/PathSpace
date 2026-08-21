# PathSpace completion roadmap

The verified private portable build is delivered. The following work is tracked in Linear for engineering completeness and public release.

## Open existing validation work

- **MOH-14 — Simple and advanced result views:** interactive keyboard/Narrator acceptance remains.
- **MOH-23 — Windows compatibility and accessibility:** Windows 10, removable media, UAC cancellation, Narrator, 200% scaling, and manual contrast validation.

## M8 — Engineering Completeness

- **MOH-25 — completed:** Bounded local audit logging is connected to scan, diagnostic, preview, and action workflows.
- **MOH-26 — completed:** Draft 2020-12 schemas and automated validation cover every emitted v1 message family.
- **MOH-27:** Add full packaged GUI end-to-end workflow tests.
- **MOH-28 — completed:** MIT licensing, third-party notices, original icon assets, and version/product metadata are included.
- **MOH-32:** Enforce documentation updates in the Definition of Done.

MOH-27 depends on MOH-25 and MOH-26 so the E2E suite validates the final observable workflows and contracts.

## M9 — Public Release Readiness

- **MOH-29:** Establish the Windows CI quality and package pipeline.
- **MOH-30:** Implement Authenticode signing and release integrity.
- **MOH-31:** Create the Windows installer and runtime-prerequisite strategy.
- **MOH-23:** Complete external Windows and accessibility validation against the release candidate.

Signing depends on legal/product identity plus CI. Installer validation follows identity and signing. External release validation follows the packaged E2E and installer work.

## Documentation rule

Every issue must update `CHANGELOG.md`, affected documentation, and Linear evidence in the same change. See [Documentation maintenance policy](technical/documentation-policy.md).
