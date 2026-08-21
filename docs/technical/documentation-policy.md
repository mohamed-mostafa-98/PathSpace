# Documentation maintenance policy

Documentation is a required deliverable, not a follow-up task.

## Mandatory rule

Every repository change must update `CHANGELOG.md` and every document affected by that change in the same commit. The contributor must then add implementation and verification evidence to the corresponding Linear issue or project update.

## Impact mapping

| Change type | Required documentation review |
|---|---|
| UI or user workflow | Root README, use cases, accessibility record, screenshots if maintained |
| CLI or PowerShell command | CLI reference, examples, safety guide, schemas |
| JSON contract/schema | Architecture, CLI reference, schema catalog, compatibility notes |
| Cleanup action/elevation | Security guide, use case, action-risk wording, verification evidence |
| Diagnostic integration | Architecture, CLI reference, guidance/use cases, privacy notes |
| Build/dependency/package | Build/release guide, prerequisites, legal notices, checksum process |
| Test or compatibility result | Project status and the relevant record under `docs/testing` |
| Release/version | README, changelog, status, release notes, installer/runtime guidance |

## Required evidence

Before completion:

- `git diff` shows the appropriate documentation changes.
- All relative Markdown links resolve.
- Commands and paths in documentation match the shipped tree.
- Test counts and compatibility claims match current command output.
- The portable package is rebuilt when shipped documentation or package contents change.
- Linear records the commit, tests, artifact, remaining risks, and accurate status.

## Exceptions

There is no blanket “docs not needed” exception. Purely internal changes may require only a concise changelog entry and confirmation that no interface or operational documentation changed, but that decision must be explicit.
