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
- [ ] Manual Narrator announcement verification.
- [ ] Manual 200% scaling and high-contrast verification.
- [ ] Manual color-contrast measurement and remediation if needed.

Narrator, scaling, high-contrast, and measured contrast checks remain manual release-signoff work because they require assistive technology or visual inspection.
