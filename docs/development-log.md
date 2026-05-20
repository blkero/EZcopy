# EZCopy Development Log

Date: 2026-05-19  
Author ID: BLKero  
Product: EZCopy  
Platform: iPhone app + desktop Chrome / Edge receiver

## Product Direction

EZCopy is positioned as an iPhone-first local media transfer tool for self-media creators. It is not intended for professional film-industry DIT workflows. The product focuses on moving iPhone-shot photos and videos to a computer through Wi-Fi, without cloud storage, third-party upload, or cellular data transfer.

The current receiver target is desktop Chrome and Edge only. Safari, Firefox, Android, and native desktop receiver apps are outside the current MVP scope.

## Timeline

### 1. Feasibility And Product Scope

The first stage clarified the viable transfer model:

- iPhone selects photos and videos from the Photos library.
- Computer opens a receiver page from the iPhone LAN address.
- Transfer should use Wi-Fi LAN only.
- Browser receiver should support metadata display, package output, and verification artifacts.
- Original embedded media metadata should be preserved by exporting original Photos resources where available.

Important feasibility conclusion:

- Direct folder writing in Chrome / Edge requires a secure browser context.
- A plain `http://iPhone-IP:8080` page cannot reliably use `showDirectoryPicker()`.
- For the old port mode, ZIP package download is the stable MVP path.
- HTTPS local service can be considered later for direct folder writing.

### 2. Project Foundation

Created the initial project structure:

- iOS SwiftUI project: `ios/EZCopy.xcodeproj`
- iOS app files:
  - `EZCopyApp.swift`
  - `ContentView.swift`
  - `MediaSelectionViewModel.swift`
  - `TransferServer.swift`
  - `Models/TransferManifest.swift`
- Browser receiver mock:
  - `web/receiver/index.html`
  - `web/receiver/standalone.html`
  - `web/receiver/src/app.js`
  - `web/receiver/src/styles.css`
- Shared schema:
  - `schemas/transfer-manifest.schema.json`
  - `shared/manifest.d.ts`
- Planning docs under `docs/`.

### 3. Photo And Video Selection

Implemented iPhone media selection with `PhotosPicker` and PhotoKit metadata extraction.

Current supported selected media metadata:

- Original filename where available
- Media type
- Creation date
- Video duration
- Pixel width and height
- Photos asset identifier

Important fix:

- Earlier builds allowed items without a Photos asset identifier into the transfer list.
- This caused browser-side `500 Internal Server Error` during ZIP creation.
- The selection flow now skips unlinked items and prompts the user to grant full Photos access or reselect local assets.

### 4. Local Wi-Fi Receiver

Implemented the iPhone-side LAN HTTP server using `NWListener`.

Current behavior:

- Server listens on port `8080`.
- App displays the Wi-Fi URL, such as `http://<iPhone-IP>:8080`.
- Server refuses to start without a Wi-Fi IPv4 address.
- Transfer is designed to use the local Wi-Fi interface, not cellular data.
- iCloud-only originals are not downloaded automatically because PhotoKit export uses network access disabled.

Endpoints implemented:

- `/` browser receiver status page
- `/manifest.json` transfer manifest
- `/download?id=...` single original resource download
- `/archive.zip` full transfer package download

### 5. Browser Receiver Direction Change

Originally, the browser page attempted direct folder writing with the File System Access API. Testing showed that Chrome / Edge blocks folder selection from a normal LAN HTTP page.

Decision:

- Keep the old port mode.
- Do not require a local receiver page.
- Use a browser ZIP download for the MVP.

Result:

- The user opens `http://iPhone-IP:8080`.
- The page shows selected media and a `Download EZCopy Package` action.
- Chrome / Edge handles the save location through the normal download flow.

### 6. Transfer Package

Implemented ZIP package creation on the iPhone.

Package contents:

- `Photos/`
- `Videos/`
- `EZCopy_Manifest.json`
- `EZCopy_Report.html`
- Optional `EZCopy_Checksums.md5`

Technical notes:

- ZIP uses no compression for speed and media-file friendliness.
- ZIP64 support was added for large files and large offsets.
- File export uses `PHAssetResourceManager.writeData`.
- Transfer progress is shown in the iPhone app.
- Browser download progress is handled by Chrome / Edge.

Current tradeoff:

- The app currently creates a temporary ZIP before sending it.
- This is stable for browser downloads but requires temporary free storage on the iPhone.

### 7. Cache Management

Added cache lifecycle handling.

Completed:

- Automatically removes the generated ZIP after browser transfer finishes.
- Attempts cleanup when transfer is interrupted.
- Adds `Cache` status to the app UI.
- Adds a `Clear Cache` button to remove old `EZCopyArchives` and `EZCopyExports` temporary data.

### 8. Optional MD5

Added a user-facing option for MD5 generation.

Completed:

- App includes a `Generate MD5 checksums` toggle.
- When enabled:
  - Source MD5 is calculated.
  - `EZCopy_Checksums.md5` is generated.
  - Manifest and report include MD5 values.
- When disabled:
  - Extra MD5 pass is skipped.
  - `.md5` file is not generated.
  - Report shows `Not enabled`.

ZIP integrity still works because ZIP-required CRC is calculated during package writing.

### 9. App Icon

Generated App Icon concepts using Image 2.0.

Chosen direction:

- Retro mid-century utility style
- Original mascot-like human figure
- Large `EZ` typography
- Local transfer / media card visual cue

Integrated assets:

- `ios/EZCopy/Assets.xcassets/AppIcon.appiconset`
- `assets/app-icon/ezcopy-app-icon-source.png`
- `assets/app-icon/ezcopy-app-icon-1024.png`

The icon was added to the Xcode asset catalog and verified through a successful iPhone build.

### 10. UI Redesign

Redesigned the main app screen based on the selected visual direction:

- Utility Pro layout as the structural base
- Light professional workspace
- Limited retro-tech brand accents from the icon
- Deep navy, cream, teal, and red accent palette

Current UI sections:

- Brand header with `EZ` identity block
- Receiver panel
- Transfer options panel
- Media picker panel
- Transfer progress panel
- Selected media list
- Footer signature

Important UI fix:

- A first redesign used system `.secondary` text too heavily.
- On real device, some text rendered almost white on a light background.
- The UI now uses a fixed muted dark gray-blue color for helper text and disabled text.

### 11. Footer Signature

Added bottom signature:

`EZCopy · Created by BLKero · 2026`

Style:

- White
- Low opacity
- Small centered footer text
- Intentionally subtle

### 12. Internal Test Baseline

Created the current project node as the first internal-test baseline.

Baseline identity:

- Version label: `v0.1.0-internal-test-baseline`
- Date: 2026-05-19
- Branch: `main`
- Purpose: preserve the first complete local-transfer MVP before further iteration

Included baseline capabilities:

- iPhone Photos media selection
- Local Wi-Fi / LAN receiver on port `8080`
- Short 6-character Access Code
- 10-minute session expiration
- One-click copy link
- Browser ZIP package download
- Manifest, HTML report, optional MD5 checksum output
- Cache clear control
- App icon and modernized UI
- Internal test introduction HTML document

Versioning decision:

- This node should be kept as a rollback point.
- Future feature work should continue from copied branches or follow-up commits.
- The local archive under `backups/` is ignored by Git and is only for local recovery.
- Git history is the preferred source for later GitHub open-source version history.

### 13. Open-Source Preparation

Prepared the repository for a future public GitHub release.

Changes:

- Added `LICENSE` with an MIT license draft.
- Added `CHANGELOG.md`.
- Added `CONTRIBUTING.md`.
- Added `SECURITY.md`.
- Added GitHub issue templates and pull request template.
- Added `docs/open-source-release-checklist.md`.
- Rewrote `README.md` for GitHub visitors.
- Removed the local Apple Developer Team ID from the Xcode project.

Open-source notes:

- The license should be confirmed before publishing.
- Device builds require each contributor to select their own Apple signing team.
- Local `backups/` content remains ignored and should not be pushed.
- Current branch for post-baseline work: `codex/internal-test-iteration`.

### 14. GitHub Public Upload

Published the project to GitHub as a public repository.

Repository:

- URL: `https://github.com/blkero/EZcopy`
- Remote: `git@github.com:blkero/EZcopy.git`
- Default branch prepared for GitHub: `main`
- Current uploaded head: `97303ef Record GitHub repository target`
- Uploaded baseline tag: `v0.1.0-internal-test-baseline`

Identity and access:

- Git author name: `blkero`
- Git author email: `283953870+blkero@users.noreply.github.com`
- Existing local commits were rewritten before upload so public history uses the GitHub identity.
- Upload uses the local SSH key configured through `core.sshCommand = ssh -i ~/.ssh/id_ed25519_github`.

Open-source package included:

- `README.md`
- `LICENSE`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- GitHub issue templates
- GitHub pull request template
- Open-source release checklist

Post-upload notes:

- The repository is public.
- The `main` branch is tracking `origin/main`.
- The baseline tag is available on GitHub for version rollback.
- Future development can continue through normal commits and tags.

## Current Build Status

Current build has been compiled and installed to the connected iPhone multiple times through `xcodebuild` and `xcrun devicectl`.

Core MVP status:

- iPhone media selection: implemented
- Local Wi-Fi server: implemented
- Browser old-port mode: implemented
- ZIP package download: implemented
- Cache cleanup: implemented
- Optional MD5: implemented
- App icon: implemented
- Modernized UI: implemented
- Short Access Code: implemented
- Internal test intro page: implemented
- Baseline archive and Git version point: created
- Public GitHub repository: published

## Known Limitations

1. Direct browser folder writing is not supported in the current old-port HTTP mode.
2. ZIP package creation requires temporary free storage on the iPhone.
3. iCloud-only originals are not automatically downloaded because network access is disabled to avoid unintended data usage.
4. Public Wi-Fi or enterprise Wi-Fi with device isolation may block computer-to-iPhone LAN access.
5. Current browser flow relies on Chrome / Edge's normal download UI for final save location.
6. The DIT report is useful for creator transfer logs, but is not intended to match professional film-industry DIT reporting standards.

## Recommended Next Steps

1. Real-world transfer QA with multiple videos and larger files.
2. Add package size preview before creating ZIP.
3. Add transfer speed and estimated remaining time.
4. Improve browser receiver page with package metadata and clearer copy.
5. Add a warning when selected files may require iCloud download.
6. Consider HTTPS local mode later for direct folder writing.
7. Consider streaming ZIP generation to reduce temporary storage usage.
8. Polish report layout and add more creator-friendly summary fields.
