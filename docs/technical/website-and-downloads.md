# Website and downloads

The dependency-free static website lives under `site` and deploys to GitHub Pages through `.github/workflows/pages.yml`. English is served from `site/index.html` and the complete Arabic RTL version from `site/ar/index.html`; each page links directly to the other and declares alternate-language metadata. It uses only committed HTML, CSS, JavaScript, original PathSpace artwork, and locally captured product screenshots; no analytics, telemetry, cookies, external fonts, runtime translation service, or other runtime service is loaded. User-facing documentation is rendered directly on the website instead of sending readers to repository Markdown.

Run the offline validator before publishing:

```powershell
.\scripts\test-site.ps1
```

The validator checks required documentation sections, screenshot assets, local references, immutable `v0.1.0-private` release links, and the absence of GitHub Markdown detours. GitHub Actions repeats this validation in normal Windows CI and before every Pages deployment.

## Product screenshots

Run `scripts\capture-site-screenshots.ps1` from an interactive Windows desktop after building the portable package. It creates disposable sample files under Public Documents, drives the real packaged UI through Windows UI Automation, captures initial, completed-summary, and recommendations states, then removes the fixture. The page overlays responsive SVG arrows and supplies numbered text explanations outside each image so the walkthrough remains understandable with zoom, keyboard navigation, or assistive technology.

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
