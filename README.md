# EZCopy

EZCopy is an iPhone-first local media copy tool for creators.

It helps you select iPhone-shot photos and videos, start a temporary local
receiver on the phone, and download one ZIP transfer package from desktop
Chrome or Edge over the same Wi-Fi / LAN.

No cloud upload. No desktop client. No intentional internet transfer for media
files. Just your iPhone, your computer, and a local network that behaves.

## Current Status

EZCopy is currently an early internal-test project.

The first preserved baseline is:

`v0.1.0-internal-test-baseline`

## Features

- Select photos and videos from the iPhone Photos library.
- Serve selected media through a local iPhone receiver.
- Open the receiver from desktop Chrome or Edge.
- Protect each receiver session with a 6-character access code.
- Expire receiver sessions after 10 minutes.
- Copy the full receiver link from the iPhone app.
- Download one ZIP package through the browser.
- Include original media, manifest JSON, HTML report, and optional MD5 checksum output.
- Show transfer/package progress on the iPhone.
- Clear temporary cache from the app.

## How It Works

1. Connect the iPhone and computer to the same Wi-Fi / LAN.
2. Select photos and videos in EZCopy.
3. Tap `Start Receiver`.
4. Open the displayed address in desktop Chrome or Edge.
5. Enter the 6-character access code, or use the copied full link.
6. Download the EZCopy ZIP package.
7. Unzip the package and review the media files and report.

## Network Notes

EZCopy's media transfer is designed to stay on the local network.

If a computer connects to the iPhone Personal Hotspot, the EZCopy media transfer
itself should still be local between the phone and computer. However, other
computer traffic such as browser tabs, cloud sync, system updates, or background
downloads may use the iPhone's cellular data.

iCloud-only originals are not automatically downloaded by EZCopy. If a selected
photo or video exists only in iCloud, download it to the iPhone first.

## Requirements

- iPhone running iOS 17 or later.
- macOS with Xcode for development builds.
- Desktop Chrome or Edge as the receiver browser.
- iPhone and computer on the same Wi-Fi / LAN.

## Build

Simulator build:

```sh
xcodebuild -project ios/EZCopy.xcodeproj -scheme EZCopy -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

For device builds, open `ios/EZCopy.xcodeproj` in Xcode and select your own
Signing & Capabilities team.

## Privacy And Security

- Media files are served from the iPhone to the browser over the local network.
- EZCopy does not intentionally upload selected media to the internet.
- Each receiver session has a short access code.
- Sessions expire after 10 minutes.
- Current local receiver traffic uses plain HTTP, not HTTPS.
- MD5 output is for integrity checking only, not cryptographic security.

Use a trusted network when transferring private media.

## Limitations

- Chrome and Edge only for the desktop receiver.
- ZIP package download is the current baseline flow.
- Direct browser folder writing is not supported in the old-port HTTP mode.
- Large packages require temporary free storage on the iPhone.
- Public, hotel, and enterprise Wi-Fi may block device-to-device LAN access.
- This is not a professional film-industry DIT tool.

## Documents

- [Product Plan](docs/product-plan.md)
- [Technical Architecture](docs/technical-architecture.md)
- [MVP Roadmap](docs/mvp-roadmap.md)
- [Phase 1 Foundation](docs/phase-1-foundation.md)
- [Phase 2 Photo Selection](docs/phase-2-photo-selection.md)
- [Phase 3 LAN Receiver](docs/phase-3-lan-receiver.md)
- [Phase 4 Browser Transfer](docs/phase-4-browser-transfer.md)
- [Local Receiver](docs/local-receiver.md)
- [Development Log](docs/development-log.md)
- [Visual Development Log](docs/development-log.html)
- [Internal Test Intro](docs/ezcopy-internal-test-intro.html)
- [Open-Source Release Checklist](docs/open-source-release-checklist.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
