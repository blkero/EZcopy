# Phase 4 Browser Transfer

Phase 4 adds the first end-to-end local copy path from the iPhone Photos library to a desktop Chrome or Edge folder.

## Included

- Browser receiver page served directly by the iPhone app.
- File System Access API folder selection.
- Automatic session folder creation.
- `Photos/` and `Videos/` output directories.
- Per-file browser-side status updates.
- iPhone-side original resource export through PhotoKit.
- HTTP download endpoint at `/download?id=<asset-id>`.
- Streaming file writes in the browser.
- Manifest output as `EZCopy_Manifest.json`.
- Basic HTML report output as `EZCopy_Report.html`.

## Browser Metadata

The receiver page and manifest expose:

- Original resource filename.
- Media type.
- Creation date.
- Pixel width and height.
- Video duration.
- Human-readable detail string.

## Test Flow

1. Open EZCopy on iPhone.
2. Select photos and videos.
3. Tap `Start Receiver`.
4. Open the displayed URL in desktop Chrome or Edge.
5. Click `Choose Folder and Copy`.
6. Choose a local destination folder.
7. Wait for every row to show `Copied`.

If Chrome disables folder selection on the iPhone URL, use the local receiver page documented in `docs/local-receiver.md`.

## Current Limits

- MD5 verification is not implemented in this phase.
- Failed file retry is not implemented yet.
- The iPhone app should stay foregrounded during transfer.
- iCloud-only originals may take time to export because PhotoKit has to download them first.
- Large videos are streamed to the browser, but this early server still handles one file request at a time.
