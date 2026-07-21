# Runtime Atlas

[![Download for macOS](https://img.shields.io/badge/Download%20for%20macOS-PKG-0A84FF?style=for-the-badge&logo=apple)][pkg]

[Latest Release][releases] · [Download ZIP][zip]

Runtime Atlas is a local-first native macOS app that shows which code is checked out in each Git worktree, which local listeners and Docker containers map to it, which logical DB profile label you assigned, and what evidence exists for the current SHA.

## What it does

- Register a Git repository and discover all of its worktrees with `git worktree list --porcelain`.
- Show branch or detached HEAD, full/short SHA, dirty state, and unavailable paths without crashing.
- Map LISTEN TCP ports to a worktree when the process cwd is inside it.
- Map running Docker containers when a host mount is inside the worktree; a missing CLI, stopped daemon, or permission failure stays a local partial error.
- Store only a user-entered logical DB label such as `refactoring_test`.
- Record command, browser, and manual evidence against the exact worktree SHA; old-SHA evidence is displayed as `STALE` without changing the original record.
- Export the same state as stable JSON through `runtime-atlas status --json`.
- Use the full app in Korean or English and switch languages immediately from the macOS Settings window.
- Check GitHub Releases while the app is open and install a newer verified `RuntimeAtlas.zip` with one click.

The app refreshes every 60 seconds while its window is open and also has a manual Refresh action. It does not install a daemon or collect state after the app exits.

The first launch follows the primary macOS language (`ko` selects Korean; other languages use English). Open **Runtime Atlas → Settings…** or press `⌘,` to choose **한국어** or **English**. The choice is saved only in the local Runtime Atlas configuration.

## Privacy boundary

Runtime Atlas reads Git metadata, `lsof` LISTEN results, process cwd where macOS permits it, and Docker container/mount/port metadata. It does **not** read `.env` files, third-party process environment variables, DB URLs, passwords, tokens, or database contents. Command stdout/stderr is passed directly to your terminal and is never stored. Common credential-shaped command arguments, note fragments, and URLs are redacted before evidence is written; do not intentionally put secrets in commands or notes. Network access is limited to checking and downloading releases from the fixed `kmg0308/runtime_atlas` GitHub repository.

Configuration and evidence are user-only, atomically replaced JSON files under:

```text
~/Library/Application Support/Runtime Atlas/
```

There is no account, telemetry, cloud sync, server, AI agent, background daemon, or silent update installation.

## Build and run locally

Requirements: macOS 13 or later and a Swift 6 toolchain.

```bash
./scripts/verify.sh
open dist/RuntimeAtlas.app
```

`verify.sh` compiles the SwiftPM test-consumer target, runs the executable `RuntimeAtlasSelfTest` suite, builds release app/CLI binaries, packages and ad-hoc signs the app, inspects ZIP/PKG payloads, exercises CLI exit/output and concurrent evidence writes, and validates the Release workflow contract.

## Install

For the normal install flow, press **Download for macOS** at the top of this README or download the latest installer directly:

```text
https://github.com/kmg0308/runtime_atlas/releases/latest/download/RuntimeAtlas.pkg
```

The PKG installs both locations:

```text
/Applications/RuntimeAtlas.app
/usr/local/bin/runtime-atlas
```

Open `RuntimeAtlas.pkg` for the normal local install. The ZIP contains `RuntimeAtlas.app`; its CLI helper is at `RuntimeAtlas.app/Contents/Helpers/runtime-atlas`.

The app uses free ad-hoc signing only. It is **not** Developer ID signed or notarized, so Gatekeeper can warn when a downloaded build is opened. Review/build the source locally before allowing it if macOS presents that warning.

## Updates

Runtime Atlas follows the same release-update pattern as token-scope: a compact banner appears when an update is available, and the **Atlas → Check for Updates…** sheet can be opened at any time.

- The app checks the latest `kmg0308/runtime_atlas` GitHub Release at launch and every 6 hours while it remains open. It does nothing after the app exits.
- **Update Now** downloads only the Release asset named `RuntimeAtlas.zip`, verifies the expected bundle ID, normal-window metadata, app executable, embedded CLI helper, and code-signature integrity, then replaces the current app and relaunches it.
- The installer keeps the old app until replacement succeeds and restores it if app or existing `/usr/local/bin/runtime-atlas` replacement fails.
- If the PKG-installed `/usr/local/bin/runtime-atlas` already exists, the in-app update refreshes it from the verified app bundle. ZIP-only installs keep using the embedded helper.
- Source-code ZIP files and assets from other repositories are not accepted by the updater.

The update is user-initiated, but these releases still use ad-hoc signing rather than Developer ID signing/notarization. Update authenticity therefore also depends on GitHub HTTPS and control of this repository; review the Release and source if that trust model is not suitable.

## CLI

Run commands from inside the worktree they belong to:

```bash
runtime-atlas status --json

runtime-atlas verify -- swift test

runtime-atlas record \
  --kind manual \
  --status BLOCKED \
  --note "Native window could not be opened" \
  --viewport 980x640
```

`verify` streams the child command's stdout/stderr, returns its original exit code, and records `PASS` for exit 0 or `FAIL` otherwise. `record` accepts `browser` or `manual` and the explicit statuses `PASS`, `FAIL`, `BLOCKED`, or `PENDING`.

## Automatic Release from main

`.github/workflows/release.yml` runs on pushes to `main` and `workflow_dispatch` with only `contents: write`. It uses GitHub run number `N` as version `0.1.N`, runs `scripts/verify.sh`, creates tag `v0.1.N`, and uploads:

- `RuntimeAtlas.zip` and `RuntimeAtlas.pkg`
- `RuntimeAtlas-0.1.N.zip` and `RuntimeAtlas-0.1.N.pkg`
- `manifest.json`

```text
push to main
→ GitHub Actions runs the full verification and packaging gate
→ fixed and versioned ZIP/PKG assets are published in a GitHub Release
→ running Runtime Atlas apps detect the newer Release
→ the user chooses Update Now to install and relaunch
```

No push or Release is performed by the local scripts. The workflow performs those remote writes only when it actually runs in GitHub Actions.

[releases]: https://github.com/kmg0308/runtime_atlas/releases/latest
[pkg]: https://github.com/kmg0308/runtime_atlas/releases/latest/download/RuntimeAtlas.pkg
[zip]: https://github.com/kmg0308/runtime_atlas/releases/latest/download/RuntimeAtlas.zip
