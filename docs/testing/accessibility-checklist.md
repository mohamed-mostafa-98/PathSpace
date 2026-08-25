# Accessibility checklist

- [x] Standard WPF controls and system focus behavior.
- [x] Keyboard-focusable target, Analyze, Cancel, tabs, checkbox, and data grids.
- [x] Accessible names for target input, live status, results, categories, and large-file tables.
- [x] Virtualized result grids.
- [x] Keyboard-focusable, accessible path filters for category and large-file results.
- [x] Explicit confirmation exposes the `Alt+I` access key for direct keyboard activation.
- [x] System color brushes replace fixed decorative colors for high-contrast compatibility.
- [x] Packaged keyboard-only automation covers target entry, Analyze activation, tab selection, path filtering, recommendation selection, preview, explicit confirmation, and execution.
- [x] Packaged UI Automation verifies screen-reader-facing names and roles, protected-diagnostics help text, and polite scan/action live regions.
- [x] Manual Narrator announcement verification (project-owner attestation, Windows 11 build 26200.9168, 2026-08-25).
- [x] Manual 200% scaling and high-contrast verification (project-owner attestation, Windows 11 build 26200.9168, 2026-08-25).
- [x] Manual color-contrast review with no remediation reported necessary (project-owner attestation, Windows 11 build 26200.9168, 2026-08-25).

The project owner reported all four manual Windows 11 checks passed. This records human sign-off rather than automated evidence; Windows 10 compatibility remains tracked separately.
