# EZCopy Open-Source Release Checklist

This checklist prepares EZCopy for a public GitHub repository. Do not push until
the maintainer confirms the repository name, license, and visibility.

## Repository State

- Current working branch: `codex/internal-test-iteration`
- Baseline tag: `v0.1.0-internal-test-baseline`
- Local baseline archive: `backups/EZCopy_v0.1.0-internal-test-baseline_2026-05-19.zip`
- Local backups are ignored by Git.

## Completed Preparation

- Added MIT license draft using `BLKero` as copyright holder.
- Added `CHANGELOG.md`.
- Added `CONTRIBUTING.md`.
- Added `SECURITY.md`.
- Added GitHub issue templates and pull request template.
- Removed local Apple Developer Team ID from the Xcode project.
- Updated README for the current ZIP-package workflow.

## Before First Push

1. Confirm the license.
2. Confirm the GitHub repository name.
3. Confirm whether the repository should be public immediately or private first.
4. Confirm whether `assets/app-icon` should be open-sourced as project assets.
5. Confirm whether the app footer should keep `Created by BLKero`.
6. Configure Git author name/email if desired before future commits.

## Suggested GitHub Repository Settings

- Repository name: `EZCopy`
- Visibility: public after final review
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

## Suggested First Release

Tag:

`v0.1.0-internal-test-baseline`

Release title:

`EZCopy v0.1.0 Internal Test Baseline`

Release notes:

- First public baseline for local Wi-Fi iPhone media transfer.
- Supports Chrome / Edge receiver flow.
- Uses ZIP package download with manifest, report, and optional MD5.
- Not production-stable; intended for internal testing and contributor review.
