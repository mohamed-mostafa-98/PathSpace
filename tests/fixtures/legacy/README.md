# Legacy diagnostic fixtures

These sanitized outputs were captured during the Windows partition-recovery cycle that preceded PathSpace. They exist only for deterministic parser tests; production code must run fresh local diagnostics and must not depend on `legacy-toolkit`.

- `docker-system-df.txt` covers a connected native Docker engine, reclaimable images, and an unused named volume.
- `wsl-list-verbose.txt` covers an Ubuntu WSL 2 distribution and Docker Desktop ownership before Docker Desktop removal.

Usernames, IDs, and application data are omitted where they are not required by a parser. The scripts in `legacy-toolkit` remain human-readable reference material, not executable product dependencies.
