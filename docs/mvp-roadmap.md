# EZCopy MVP Roadmap

## Phase 1: Foundation

Status: scaffolded in `docs/phase-1-foundation.md`.

- Create iOS app project named EZCopy.
- Create browser receiver project.
- Define shared manifest schema.
- Build a local mock transfer flow with sample files.
- Implement browser support detection for Chrome and Edge.

## Phase 2: iPhone Media Selection

Status: initial Photos picker and selected media list scaffolded in `docs/phase-2-photo-selection.md`.

- Add Photos permission flow.
- Add photo/video picker.
- Build selected media list UI.
- Resolve selected assets to exportable resources.
- Handle common file names, sizes, media types, and created dates.

## Phase 3: Local Transfer Session

Status: initial iPhone HTTP receiver endpoint scaffolded in `docs/phase-3-lan-receiver.md`.

- Start local server from iPhone.
- Display session URL.
- Add QR code.
- Serve browser receiver page.
- Establish browser-to-iPhone connection.
- Send session manifest.

## Phase 4: File Writing

Status: initial browser folder-copy flow scaffolded in `docs/phase-4-browser-transfer.md`.

- Ask browser user to choose destination folder.
- Create EZCopy session folder.
- Create `Photos/` and `Videos/`.
- Receive one file in chunks.
- Write chunks incrementally.
- Expand to multi-file queue transfer.

## Phase 5: Verification

- Calculate source MD5 on iPhone.
- Calculate received MD5 in browser.
- Compare checksums per file.
- Show pass/fail status.
- Add retry for failed files.

## Phase 6: Reports

- Write `EZCopy_Report.html`.
- Write `EZCopy_Manifest.json`.
- Write `EZCopy_Checksums.md5`.
- Make reports readable and useful for creators.

## Phase 7: Polish

- Improve progress UI.
- Add transfer speed and remaining time.
- Add clear iCloud original download messaging.
- Add keep-awake guidance during large transfers.
- Add unsupported browser message.
- Add basic error recovery.

## MVP Acceptance Criteria

- User can select iPhone photos and videos.
- User can open an EZCopy session in desktop Chrome or Edge.
- User can choose a destination folder from the browser.
- Files are copied into a structured session folder.
- Copied files preserve original embedded media metadata where original resources are available.
- Every copied file gets an MD5 verification result.
- A readable transfer report is created at the end.
- Unsupported browsers are rejected with a clear message.
