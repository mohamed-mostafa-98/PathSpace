# PathSpace completion roadmap

The verified private portable build is delivered. The following work is tracked in Linear for engineering completeness and public release.

## Open existing validation work

- **MOH-14 — completed:** Result views, filtering/sorting coverage, and packaged keyboard navigation pass.
- **MOH-23 — Windows compatibility and accessibility:** Windows 11 UAC cancellation, removable-media scan, and user-attested Narrator, 200% scaling, high-contrast, and contrast checks pass; Windows 10 validation remains.

## M8 — Engineering Completeness

- **MOH-25 — completed:** Bounded local audit logging is connected to scan, diagnostic, preview, and action workflows.
- **MOH-26 — completed:** Draft 2020-12 schemas and automated validation cover every emitted v1 message family.
- **MOH-27 — completed:** Three packaged GUI workflows cover complete, cancellation, and keyboard-only paths with TRX release evidence.
- **MOH-28 — completed:** MIT licensing, third-party notices, original icon assets, and version/product metadata are included.
- **MOH-32 — completed:** Documentation updates and Linear evidence are enforced in the Definition of Done.

MOH-27 validated the final observable workflows after MOH-25 and MOH-26 completed.

## M9 — Public Release Readiness

- **MOH-29 — completed:** The GitHub remote and Windows CI pipeline are active; hosted run 8 passed all quality/package/MSI gates and retained test, portable, and installer artifacts.
- **MOH-30 — in progress:** Signing, secret handling, timestamp/signature enforcement, post-signing checksums, release workflow, tamper tests, and the protected `release-signing` GitHub environment are implemented; real-certificate, CA timestamp configuration, and clean-host proof remain.
- **MOH-31 — in progress:** The WiX per-machine MSI, embedded-runtime strategy, stable upgrade/Start-menu identity, CI structural verification, lifecycle harness, and unsigned Windows 11 install/upgrade/uninstall proof are complete; signed Windows 10/11 clean-host evidence remains.
- **MOH-77 — completed:** The dependency-free GitHub Pages website and immutable 0.1.0-private portable/MSI prerelease downloads are live with matching checksums and explicit unsigned-preview labeling.
- **MOH-78 — completed:** Complete user documentation and real annotated packaged-GUI walkthroughs are rendered directly on the live website without repository-Markdown detours; Pages and Windows CI validation pass.
- **MOH-79 — completed:** A complete Arabic RTL website is live alongside English with static language switching, alternate-language metadata, passing route/reference validation, GitHub Pages, and Windows CI.
- **MOH-23:** Complete Windows 10 validation against the release candidate.

Signing depends on legal/product identity plus CI. Installer validation follows identity and signing. External release validation follows the packaged E2E and installer work.

## Documentation rule

Every issue must update `CHANGELOG.md`, affected documentation, and Linear evidence in the same change. See [Documentation maintenance policy](technical/documentation-policy.md).
