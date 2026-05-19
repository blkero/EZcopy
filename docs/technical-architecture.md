# EZCopy Technical Architecture

## Overview

EZCopy has two runtime sides:

- iPhone sender: native iOS app built with Swift and SwiftUI.
- Browser receiver: local web page opened in desktop Chrome or Edge.

The iPhone exposes a local transfer session over the LAN. The browser connects to the iPhone, chooses a local save directory, receives files in chunks, writes them to disk, and verifies integrity.

## iPhone Sender

### Recommended Stack

- Swift
- SwiftUI
- PhotoKit
- Network framework or lightweight embedded HTTP/WebSocket server
- Crypto implementation for MD5
- QR code generation for session URL

### Main Modules

- `PhotoPicker`: handles user media selection.
- `MediaExporter`: resolves selected Photos assets into original file resources.
- `ChecksumService`: calculates MD5 for exported files.
- `TransferServer`: hosts the local receiver page and transfer endpoints.
- `TransferSession`: owns selected files, progress, state, and retry information.
- `SessionSecurity`: handles pairing code or session token.

### PhotoKit Strategy

Use PhotoKit to access selected assets and export original resources where possible.

Important behaviors:

- Avoid image/video recompression in MVP.
- Preserve embedded EXIF and QuickTime metadata by copying original resources.
- Detect assets that require iCloud download.
- Store each exported item in a temporary app session directory before transfer, or stream from the resource export target.

## Browser Receiver

### Recommended Stack

- Plain TypeScript or a lightweight frontend framework.
- File System Access API for folder selection and file writing.
- WebSocket or HTTP range/chunk protocol for transfer.
- JS/WASM MD5 library for incremental hashing.

### Browser Support

Only support desktop Chrome and Edge.

The receiver must block unsupported browsers because direct directory writing depends on `showDirectoryPicker()`.

### Main Modules

- `BrowserSupport`: validates Chrome/Edge and File System Access API availability.
- `DirectoryWriter`: creates session folders and writes files incrementally.
- `TransferClient`: communicates with the iPhone transfer server.
- `ChecksumWorker`: calculates received MD5 off the main UI thread.
- `ReportWriter`: writes HTML, JSON, and MD5 report files.
- `ProgressStore`: tracks file and session progress.

## Transfer Protocol

### Session Manifest

Before transfer starts, the iPhone sends a manifest:

```json
{
  "sessionId": "2026-05-19T15-30-00",
  "deviceName": "iPhone",
  "createdAt": "2026-05-19T15:30:00+08:00",
  "files": [
    {
      "id": "asset-001",
      "originalName": "IMG_0014.MOV",
      "mediaType": "video",
      "size": 2583912048,
      "createdAt": "2026-05-18T21:10:03+08:00",
      "sourceMd5": "..."
    }
  ]
}
```

### Chunk Transfer

Recommended MVP approach:

- Transfer one file at a time.
- Use fixed-size chunks, such as 8 MB.
- Browser acknowledges file completion.
- Browser compares received MD5 with source MD5.
- Failed files can be retried from the beginning in MVP.

Resume from partial chunks can be added later.

## Output Structure

```text
EZCopy_2026-05-19_1530/
├── Photos/
│   ├── IMG_0012.HEIC
│   └── IMG_0013.JPG
├── Videos/
│   ├── IMG_0014.MOV
│   └── IMG_0015.MP4
├── EZCopy_Report.html
├── EZCopy_Manifest.json
└── EZCopy_Checksums.md5
```

## Report Files

### EZCopy_Report.html

Human-readable transfer report:

- App name and version.
- Device name.
- Transfer start and finish time.
- File count.
- Photo count.
- Video count.
- Total bytes.
- Success count.
- Failure count.
- Per-file status table.

### EZCopy_Manifest.json

Machine-readable session manifest plus transfer results.

### EZCopy_Checksums.md5

Plain checksum list:

```text
d41d8cd98f00b204e9800998ecf8427e  Videos/IMG_0014.MOV
```

## Known Technical Risks

- File System Access API requires supported desktop Chromium browsers.
- Local network permission must be handled clearly on iOS.
- iCloud originals may need download before transfer.
- Large video files can stress browser memory if chunks are not streamed carefully.
- iOS background execution is limited, so long transfers should keep the app foregrounded.
- MD5 is for integrity checking only, not security.
