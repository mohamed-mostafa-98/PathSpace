# PathSpace documentation

This directory contains the product, engineering, operational, and validation documentation for PathSpace.

## Documentation map

- [Technical documentation](technical/README.md) — architecture, components, contracts, security model, CLI, build, testing, and release procedures.
- [Use cases](use-cases/README.md) — supported user journeys, actors, preconditions, safe flows, and expected outcomes.
- [Completion roadmap](project-roadmap.md) — open Linear work organized by engineering and public-release milestones.
- [Documentation maintenance policy](technical/documentation-policy.md) — mandatory documentation and Linear updates for every change.
- [Accessibility checklist](testing/accessibility-checklist.md) — automated evidence and remaining interactive checks.
- [Windows compatibility record](testing/windows-compatibility.md) — tested hosts, drives, package behavior, and outstanding compatibility gates.
- [PathSpace 0.1.0-private release notes](releases/0.1.0-private.md) — downloads, highlights, verification, known gates, and safety.
- [Website and downloads](technical/website-and-downloads.md) — GitHub Pages deployment, validation, and release-asset policy.
- [Installer and runtime strategy](technical/installer-and-runtime.md) — MSI choice, embedded runtime, install/upgrade/uninstall behavior, and portable fallback.
- [Product design specification](superpowers/specs/2026-08-20-pathspace-design.md) — original approved scope and design decisions.
- [Implementation plan](superpowers/plans/2026-08-20-pathspace-implementation.md) — milestone-by-milestone engineering plan.

## Intended audiences

- End users should start with the project [README](../README.md) and [use cases](use-cases/README.md).
- Developers and maintainers should start with the [technical overview](technical/README.md).
- Contributors must follow the repository [contribution guide](../CONTRIBUTING.md) and update the [changelog](../CHANGELOG.md).
- Release reviewers should use the [build and release guide](technical/build-test-release.md) and validation records under `testing`.

PathSpace operates fully offline. Documentation must not instruct the application to upload scan results, telemetry, or user paths.
