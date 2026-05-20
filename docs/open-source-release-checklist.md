# EZCopy Open-Source Release Checklist

This checklist records the open-source release preparation and first public
GitHub upload for EZCopy.

## Repository State

- Current public branch: `main`
- GitHub repository: `https://github.com/blkero/EZcopy`
- Git remote: `git@github.com:blkero/EZcopy.git`
- Uploaded head: `97303ef Record GitHub repository target`
- Baseline tag: `v0.1.0-internal-test-baseline`
- Local baseline archive: `backups/EZCopy_v0.1.0-internal-test-baseline_2026-05-19.zip`
- Local backups are ignored by Git.
- Public upload date: 2026-05-20

## Completed Preparation

- Added MIT license draft using `BLKero` as copyright holder.
- Added `CHANGELOG.md`.
- Added `CONTRIBUTING.md`.
- Added `SECURITY.md`.
- Added GitHub issue templates and pull request template.
- Removed local Apple Developer Team ID from the Xcode project.
- Updated README for the current ZIP-package workflow.
- Configured Git author as `blkero <283953870+blkero@users.noreply.github.com>`.
- Rewrote local commit authors before upload.
- Uploaded `main` and `v0.1.0-internal-test-baseline`.

## Completed First Push

1. License confirmed as MIT for the first public upload.
2. Repository confirmed as public.
3. Repository name confirmed as `EZcopy`.
4. Git author email confirmed as the GitHub noreply address.
5. `main` pushed to GitHub.
6. Baseline tag pushed to GitHub.

## Suggested GitHub Repository Settings

- Repository name: `EZcopy`
- Visibility: public
- Default branch: `main`
- Enable Issues
- Enable Discussions only if you want public support threads
- Enable private vulnerability reporting
- Add topics:
  - `ios`
  - `swiftui`
  - `local-network`
  - `photo-transfer`
  - `creator-tools`

## First Release Reference

Tag:

`v0.1.0-internal-test-baseline`

Release title:

`EZCopy v0.1.0 Internal Test Baseline`

Release notes:

- First public baseline for local Wi-Fi iPhone media transfer.
- Supports Chrome / Edge receiver flow.
- Uses ZIP package download with manifest, report, and optional MD5.
- Not production-stable; intended for internal testing and contributor review.

## Remaining Repository Tasks

1. Confirm GitHub repository topics.
2. Decide whether to enable Discussions.
3. Enable private vulnerability reporting if available.
4. Create a GitHub Release from `v0.1.0-internal-test-baseline` if a release page is desired.
5. Continue future changes with regular commits and new version tags.
