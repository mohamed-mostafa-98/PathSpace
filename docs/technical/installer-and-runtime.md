# Installer and runtime strategy

## Distribution decision

PathSpace uses a per-machine x64 MSI built with pinned WiX Toolset 5.0.2. MSI fits the existing classic WPF application and elevated worker without adding MSIX identity or container restrictions. The installer creates `%ProgramFiles%\PathSpace`, an advertised PathSpace Start-menu shortcut, Windows uninstall registration, and a stable upgrade identity. Product codes are deterministic per three-field product version and change when that version changes.

The MSI is self-contained: the .NET 8 Windows Desktop runtime is embedded and no separate runtime download or prerequisite prompt is required. The build fails unless `coreclr.dll`, `hostfxr.dll`, `PresentationFramework.dll`, and the runtime license/third-party notice files are present. This makes installation deterministic and offline at the cost of a larger download.

The smaller framework-dependent portable folder remains available as a fallback for users who already have the .NET 8 Desktop Runtime or cannot use MSI installation.

## Build and verify

```powershell
dotnet tool restore
.\scripts\build-installer.ps1
.\scripts\test-installer.ps1
```

The pinned tool manifest restores WiX; no global WiX installation is required. Output is `artifacts\installer\PathSpace-0.1.0-win-x64.msi` with a sibling `SHA256SUMS.txt`. The build runs native Windows Installer ICE validation. Structural verification then checks product/version/upgrade metadata, embedded-runtime files, all-users Start-menu identity, and a disposable administrative extraction without installing the product.

## Install and uninstall

Use the signed public-release MSI from an administrator-approved Windows session. A normal interactive launch of the MSI requests elevation because PathSpace is installed for all users. After installation, PathSpace itself starts normally and requests elevation only for protected scans or confirmed actions.

Uninstall from **Settings > Apps > Installed apps > PathSpace**, or use the MSI through Windows Installer. A higher product version with the same upgrade code performs a major upgrade; downgrades are rejected.

The portable fallback is not registered with Windows Installer. Extract it to a user-controlled directory, launch `PathSpace.App.exe`, and remove the extracted folder to uninstall it.

## Clean-host lifecycle gate

From elevated PowerShell on a disposable clean Windows host, provide two signed MSI versions:

```powershell
.\scripts\test-installer-lifecycle.ps1 `
  -BaselineInstallerPath .\PathSpace-0.1.0-win-x64.msi `
  -UpgradeInstallerPath .\PathSpace-0.1.1-win-x64.msi
```

The check installs the baseline, verifies installed files and the Start-menu shortcut, upgrades, uninstalls, and verifies removal. Run it on Windows 10 x64 and Windows 11 x64. Logs are deleted after success and retained under `%TEMP%` on failure.

MOH-31 remains incomplete until signed clean install/upgrade/uninstall evidence exists on both supported Windows versions.
