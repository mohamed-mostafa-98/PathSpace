# Contributing to PathSpace

PathSpace prioritizes offline operation, explicit consent, measurable evidence, and recoverable behavior. Contributions must preserve those properties.

## Change workflow

1. Link the change to a Linear issue.
2. Create a focused branch or worktree.
3. Add or update tests before claiming behavior is complete.
4. Implement the smallest complete solution that satisfies the issue acceptance criteria.
5. Update `CHANGELOG.md` and all affected documentation in the same commit.
6. Run relevant .NET, Pester, schema, Markdown-link, and package checks.
7. Add verification evidence to Linear and update issue status accurately.

## Documentation impact checklist

For every change, review:

- Root `README.md` for product entry points and supported behavior
- `docs/technical` for architecture, CLI, security, build, and operations
- `docs/use-cases` for user workflows and safety expectations
- `docs/testing` for compatibility/accessibility evidence
- `PROJECT_STATUS.md` for delivered and outstanding work
- `CHANGELOG.md` for the user/developer-visible history
- `docs/README.md` for navigation

Documentation-only changes still require link validation and a changelog entry when they materially alter guidance or policy.

## Required validation

```powershell
dotnet test .\tests\PathSpace.Contracts.Tests\PathSpace.Contracts.Tests.csproj
dotnet test .\tests\PathSpace.Worker.Tests\PathSpace.Worker.Tests.csproj
dotnet test .\tests\PathSpace.App.Tests\PathSpace.App.Tests.csproj
Invoke-Pester -Script @('.\tests\engine','.\tests\signing')
```

Package-affecting changes must rebuild `artifacts\PathSpace-win-x64`, verify `SHA256SUMS.txt`, and run `scripts\verify-portable-action.ps1` where relevant. Installer changes must also run `scripts\build-installer.ps1` and `scripts\test-installer.ps1`; release acceptance requires the elevated lifecycle script on clean Windows 10/11 hosts.

Before opening or merging a pull request, run the same local checks used by Windows CI:

```powershell
dotnet test .\PathSpace.sln -c Release
Invoke-Pester -Script @('.\tests\engine','.\tests\signing')
.\scripts\test-markdown-links.ps1
.\scripts\build-portable.ps1
.\scripts\test-package-checksums.ps1
pwsh -NoProfile -File .\scripts\verify-portable-action.ps1
.\scripts\build-installer.ps1
.\scripts\test-installer.ps1
```

The hosted workflow must be green for its exact commit. Interactive packaged-GUI and external Windows/accessibility evidence remain separate required release gates and must not be represented as hosted-CI coverage.

## Safety review

- Do not broaden action targets or elevation scope without explicit threat analysis and tests.
- Do not add telemetry, uploads, accounts, or network scanning.
- Do not auto-delete Docker volumes, WSL distributions, databases, or unknown application data.
- Do not represent estimated recovery as measured recovery.
- Treat UAC cancellation and unavailable diagnostics as safe, normal outcomes.
