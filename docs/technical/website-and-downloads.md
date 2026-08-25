# Website and downloads

The dependency-free static website lives under `site` and deploys to GitHub Pages through `.github/workflows/pages.yml`. It uses only committed HTML, CSS, JavaScript, and original PathSpace artwork; no analytics, telemetry, cookies, external fonts, or runtime services are loaded.

Run the offline validator before publishing:

```powershell
.\scripts\test-site.ps1
```

The validator checks required sections, local assets, and immutable `v0.1.0-private` release links. GitHub Actions repeats this validation in normal Windows CI and before every Pages deployment.

## Release assets

The `v0.1.0-private` GitHub prerelease contains:

- `PathSpace-0.1.0-win-x64.msi`
- `PathSpace-0.1.0-private-portable-win-x64.zip`
- `SHA256SUMS-release.txt`

The website intentionally labels these packages as an unsigned private preview. Do not remove that warning until MOH-30 and MOH-31 have trusted publisher-signing and signed clean-host lifecycle evidence.

## Publishing a later version

1. Complete the release gates and update product/version metadata.
2. Build both packages from the exact tagged commit.
3. Sign and timestamp production packages before computing release checksums.
4. Update versioned links and release notes in `site/index.html`.
5. Run site, package, signature, checksum, and Markdown validation.
6. Push, wait for CI, create the GitHub release, and verify every public download.
