# Security and cleanup safety

## Safety principles

1. Scan before recommending.
2. Never preselect cleanup actions.
3. Preview exact targets before confirmation.
4. Require explicit confirmation for every action.
5. Elevate only the narrow protected operation.
6. Verify the outcome before claiming recovery.
7. Label irreversible behavior clearly.

## Path protections

The engine rejects unknown actions, UNC paths, wildcard targets, unresolved unsafe values, drive-root deletion targets, and unsafe reparse-point traversal. Scanning reports inaccessible paths as warnings rather than broadening privileges silently.

## Manifest protections

The worker validates:

- strict allowed JSON properties and no duplicate properties;
- schema and message kind;
- allow-listed action ID;
- exact local target scope;
- nonce and five-minute expiry;
- canonical SHA-256 manifest digest;
- elevation expectations.

The digest detects accidental or local manifest mutation; it is not a publisher code-signing certificate. Public distribution should add Authenticode signing for executables and scripts.

## Cleanup classifications

- Temporary files and npm-cache cleanup permanently delete only unlocked children after confirmation.
- Recycle Bin and Windows component cleanup are explicitly irreversible.
- Hibernation changes are reversible but affect Hibernate and potentially Fast Startup.
- Volume optimization delegates to Windows `Optimize-Volume`.
- Docker volumes, WSL distributions, and unknown Notion data are guided only and are never automatically deleted.
- Claude relocation copies and verifies first, retains rollback, creates a verified junction, and supports explicit rollback.

## Operator rules

- Close applications that own data before cleanup or migration.
- Keep backups for databases and application runtimes.
- Never delete `pagefile.sys`, `hiberfil.sys`, a VHDX, or an application root manually.
- Treat an unverified outcome as incomplete, even if the command returned success.
