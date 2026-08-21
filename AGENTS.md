# PathSpace repository instructions

These instructions apply to every contributor and automated agent working in this repository.

## Documentation is part of every change

Every source, configuration, schema, test, packaging, dependency, security, UI, workflow, or release change must include documentation updates in the same commit.

At minimum:

1. Add an entry under `Unreleased` in `CHANGELOG.md`.
2. Update each affected technical guide, CLI reference, use case, safety rule, test record, README, or project-status statement.
3. Update documentation navigation when files are added, renamed, or removed.
4. Record completed work and verification evidence in the corresponding Linear issue/project update.
5. Validate local Markdown links before considering the change complete.

Do not make meaningless documentation edits merely to satisfy the rule. Explain the real user, developer, operational, security, or release impact. If behavior truly does not change, the changelog entry may say that the change is internal and identify the verification performed.

## Definition of Done

A change is not done until code/configuration, tests, documentation, package implications, and Linear state agree. Never mark a task complete when documentation describes behavior that is not implemented or when implementation has changed without updating its documentation.
