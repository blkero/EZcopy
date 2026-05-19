# EZCopy Product Plan

## Positioning

EZCopy is a lightweight iPhone media copy app for self-media creators. It focuses on one job: copy phone-shot photos and videos to a computer through the local network with a clear completion report and checksum verification.

The product should feel simple, fast, and reliable. It is not positioned as a professional DIT tool for film sets.

## Target Users

- Short-video creators.
- Vloggers.
- Small content teams.
- Users who shoot on iPhone and edit on a laptop or desktop.
- Users who want to avoid AirDrop instability, cloud sync delays, or cable import workflows.

## Core User Flow

1. Open EZCopy on iPhone.
2. Select photos and videos from the Photos library.
3. EZCopy starts a local transfer session and displays a browser URL and QR code.
4. Open the URL in desktop Chrome or Edge.
5. Browser page shows the selected media list and total size.
6. User chooses a destination folder.
7. User starts the copy.
8. EZCopy transfers files over the local network.
9. Browser writes files into the chosen folder.
10. Each file is verified with MD5.
11. Browser writes the transfer report, manifest, and checksum file.

## MVP Features

### iPhone App

- Request Photos permission.
- Select photo and video assets.
- Filter out unsupported asset types in MVP.
- Export original media resources where available.
- Calculate source MD5 for each file.
- Start local HTTP/WebSocket transfer service.
- Display local URL, QR code, connection state, and transfer progress.
- Warn when selected assets may require iCloud original download.

### Browser Receiver

- Support desktop Chrome and Edge.
- Detect unsupported browsers and show a blocking message.
- Use `showDirectoryPicker()` to ask the user to choose a destination folder.
- Create a session folder such as `EZCopy_2026-05-19_1530`.
- Split files into `Photos/` and `Videos/`.
- Receive file chunks and write them incrementally.
- Calculate received MD5.
- Mark each file as passed or failed.
- Generate:
  - `EZCopy_Report.html`
  - `EZCopy_Manifest.json`
  - `EZCopy_Checksums.md5`

## Supported Media in MVP

- Photos: HEIC, JPG, JPEG, PNG when present in Photos.
- Videos: MOV, MP4.

MVP should prioritize media shot by the iPhone camera app or common creator camera apps that save standard photo/video files into the Photos library.

## Out of Scope for MVP

- Safari and Firefox support.
- iCloud cloud-to-computer transfer without local iPhone download.
- RAW and ProRAW special handling.
- Live Photo paired export.
- Advanced album/folder reconstruction.
- Resume after app termination.
- Multi-device concurrent transfer.
- Remote internet transfer.
- PDF report generation.

## Product Principles

- No compression by default.
- No account required.
- No cloud dependency.
- Clear status before, during, and after copy.
- Failed files should be obvious and retryable.
- Reports should use plain language, not professional film-set terminology.
