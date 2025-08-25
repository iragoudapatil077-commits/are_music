Release & Hosting Guide

Steps to publish Windows installer to GitHub Releases and enable auto-update:

1) Build locally

```powershell
flutter pub get
flutter build windows --release
```

2) Package into an installer (local/in CI)
- Use Inno Setup on Windows to create a single EXE installer from `build\windows\x64\runner\Release`.
- Or create a ZIP archive containing the Release folder.

3) Create a Git tag and push

```powershell
git tag v2.0.14
git push origin v2.0.14
```

The included GitHub Actions workflow will build the Windows release when a tag `v*` is pushed and publish artifacts to a GitHub Release.

4) Publish assets
- The workflow will upload the release files.
- After release is available, update `assets/release_manifest_example.json` (or host a simple `latest.json`) at a stable URL and point `appConfig.updateUri` to it if you prefer using a simple manifest.

Hosting a simple `latest.json` on GitHub
- Option A: GitHub Pages
	- Add `latest.json` to the `gh-pages` branch (or `docs/` folder on main) and enable GitHub Pages. Then your manifest will be available at `https://<your-username>.github.io/<repo>/latest.json`.
- Option B: Raw GitHub URL
	- Commit `latest.json` to the `main` branch and use the raw URL:
		`https://raw.githubusercontent.com/<user>/<repo>/main/latest.json`

To point the app to the hosted manifest, set the runtime environment variable `ARE_UPDATE_URI` to the manifest URL if you built with the environment override, or update `lib/app_config.dart` with the desired URL and rebuild.

Helper: create a GitHub repo and push from this project
- Windows (PowerShell): run the helper script included in `scripts/create_github_repo.ps1`.
	- Example:
		```powershell
		pwsh scripts\create_github_repo.ps1 -orgOrUser "iragoudapatil077-commits" -repo "are_music" -visibility "public"
		```
	- Prerequisites: GitHub CLI (`gh`) installed and authenticated (`gh auth login`).

Trigger the CI manually
- You can dispatch the workflow from the GitHub UI (Actions -> Build and Release Windows -> Run workflow) or push a tag:
	```powershell
	git tag v2.0.14
	git push origin v2.0.14
	```

Publish `latest.json` on GitHub Pages
- Add `latest.json` to the `docs/` folder on `main` or use `gh-pages` branch and enable GitHub Pages. Then point `ARE_UPDATE_URI` to:
	`https://<your-username>.github.io/<repo>/latest.json`

Set `ARE_UPDATE_URI` at build time in CI
- In your GitHub Actions workflow, you can set `--dart-define` when building to bake the manifest URL into the binary:
	```yaml
	- name: Build Windows Release
		run: flutter build windows --release --no-tree-shake-icons --dart-define=ARE_UPDATE_URI="https://<your-username>.github.io/<repo>/latest.json"
	```

5) Auto-update flow (app-side)
- App currently calls `checkUpdate()` which will use the GitHub Releases API by default. If you want simple manifest hosting, set `appConfig.updateUri` to your `https://yourdomain.com/latest.json`.

6) Code signing
- Sign your installer with a code signing cert to reduce SmartScreen warnings.

7) SHA256
- Publish the SHA256 of the installer next to the download link.

CI notes
- To sign in CI, store your certificate/password in GitHub Secrets and sign during the workflow.
