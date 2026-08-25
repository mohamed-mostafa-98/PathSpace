# PathSpace

PathSpace is an offline Windows 10/11 storage analyzer and guided-cleanup application. It explains where local disk space is used, recommends evidence-based recovery options, and requires an exact preview plus explicit confirmation before any supported cleanup action.

## Highlights

- Analyze local fixed drives, removable drives, or individual folders.
- View categorized usage, large files, warnings, filters, and raw diagnostics.
- Diagnose Docker, WSL, Notion, Claude, pagefile, hibernation, and volume storage.
- Run normally; request administrator approval only for protected diagnostics or actions.
- Export local JSON, redacted JSON, and CSV reports.
- Operate fully offline with no telemetry, accounts, uploads, or network scanning.
- Use guarded allow-listed actions with post-action verification.
- Keep bounded, rotating workflow audit records locally without recording raw target paths.
- Validate the packaged WPF workflow with opt-in disposable-fixture GUI automation.

## Run PathSpace

The current portable build is located at:

```text
artifacts\PathSpace-win-x64\PathSpace.App.exe
```

The package is framework-dependent and requires the .NET 8 Desktop Runtime.

The MSI build embeds the .NET 8 Desktop Runtime for offline installation and is located at:

```text
artifacts\installer\PathSpace-0.1.0-win-x64.msi
```

Public distribution remains gated on publisher signing and clean Windows 10/11 install, upgrade, and uninstall evidence.

Basic workflow:

1. Select a drive or browse to a local folder.
2. Choose **Analyze** and wait for the complete snapshot.
3. Review Summary, Categories, Large files, Recommendations, Advanced diagnostics, and Guidance.
4. Export a report or select an actionable recommendation.
5. Review the exact preview and risk label before confirming an action.

## Documentation

- [Documentation hub](docs/README.md)
- [Technical documentation](docs/technical/README.md)
- [Architecture](docs/technical/architecture.md)
- [CLI reference](docs/technical/cli-reference.md)
- [Security and cleanup safety](docs/technical/security-and-safety.md)
- [Authenticode signing and release integrity](docs/technical/signing-and-release-integrity.md)
- [Installer and runtime strategy](docs/technical/installer-and-runtime.md)
- [Build, test, and release guide](docs/technical/build-test-release.md)
- [User use cases](docs/use-cases/README.md)
- [Completion roadmap](docs/project-roadmap.md)
- [Contributing and Definition of Done](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)
- [License](LICENSE) and [third-party notices](THIRD-PARTY-NOTICES.md)
- [Windows compatibility record](docs/testing/windows-compatibility.md)
- [Accessibility checklist](docs/testing/accessibility-checklist.md)
- [Windows CI workflow](.github/workflows/windows-ci.yml)

## Repository structure

| Path | Purpose |
|---|---|
| `src/PathSpace.App` | .NET 8 WPF graphical application |
| `src/PathSpace.Contracts` | Versioned JSON contracts |
| `src/PathSpace.Worker` | Strict normal/elevated action worker |
| `engine/PathSpace.Engine` | Reusable PowerShell scanner, diagnostics, recommendations, and actions |
| `cli` | JSONL command-line interface |
| `schemas` | JSON schema definitions |
| `tests` | xUnit, Pester, fixtures, and integration tests |
| `legacy-toolkit` | Reviewed standalone diagnostics and guided migration tools |
| `scripts` | Build and package verification scripts |
| `installer` | WiX MSI definition and stable product/upgrade identity |

## Build and test

```powershell
dotnet restore .\PathSpace.sln
dotnet test .\tests\PathSpace.Contracts.Tests\PathSpace.Contracts.Tests.csproj
dotnet test .\tests\PathSpace.Worker.Tests\PathSpace.Worker.Tests.csproj
dotnet test .\tests\PathSpace.App.Tests\PathSpace.App.Tests.csproj
Invoke-Pester -Script @('.\tests\engine','.\tests\signing')
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-portable.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-installer.ps1
```

Run the packaged GUI E2E suite from an interactive Windows desktop:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-packaged-gui.ps1 -DotNetPath 'C:\path\to\dotnet.exe'
```

Current automated coverage includes 12 contract/schema tests, 6 worker-security tests, 17 application/accessibility tests, 23 PowerShell engine/signing tests, 3 packaged GUI workflows, 1 packaged screen-reader-semantics check, and 1 separately enabled UAC-cancellation workflow.

The Windows CI workflow runs the non-interactive quality suites, Markdown/schema checks, portable build, checksum verification, packaged-worker smoke test, self-contained MSI build, and MSI structural/extraction verification. It retains test evidence and both package forms for 30 days. Packaged GUI automation and signed clean-host installer lifecycle testing remain interactive host gates; the unsigned Windows 11 lifecycle already passes.

## Product identity and version

The current private build is version `0.1.0-private`. Executables carry PathSpace product, company, copyright, file-version, and application-icon metadata. Source is licensed under the MIT License; redistribution must retain the license and applicable third-party notices.

## Safety boundaries

- Cleanup actions are never preselected.
- Unknown commands, wildcards, UNC deletion targets, and drive-root deletions are rejected.
- Docker volumes, WSL distributions, and unknown application data are guided only.
- Registry cleaning is deliberately out of scope.
- Volume optimization uses Windows `Optimize-Volume`; PathSpace does not implement a custom defragmenter.

## Project tracking

- [Project status](PROJECT_STATUS.md)
- [GitHub repository](https://github.com/mohamed-mostafa-98/PathSpace)
- [Windows CI](https://github.com/mohamed-mostafa-98/PathSpace/actions/workflows/windows-ci.yml)
- [Linear project](https://linear.app/mohamed-mostafa/project/pathspace-04c36f87d38a)
- [Design specification](docs/superpowers/specs/2026-08-20-pathspace-design.md)
- [Implementation plan](docs/superpowers/plans/2026-08-20-pathspace-implementation.md)

## Documentation rule

Every source, configuration, schema, test, packaging, or release change must update `CHANGELOG.md` and all affected documentation in the same commit, then record verification evidence in Linear. See [CONTRIBUTING.md](CONTRIBUTING.md) and the [documentation policy](docs/technical/documentation-policy.md).

The private Windows 11 build is verified. Windows 10, removable-media, Narrator, and manual 200% scaling checks remain explicit public-release gates.

On an external Windows 10/11 validation host, run `validation\collect-windows-host-evidence.ps1` from the portable package. It writes a local JSON report containing package identity, OS/build, drive/media types, DPI/high-contrast state, normal GUI launch/TCP evidence, and an optional CLI scan result; it never uploads data or performs cleanup.
