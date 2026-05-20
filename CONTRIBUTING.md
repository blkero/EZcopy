# Contributing to EZCopy

Thanks for considering contributing to EZCopy.

EZCopy is currently an early internal-test project focused on one workflow:
copying iPhone-shot photos and videos to a computer over a local Wi-Fi / LAN
connection.

## Development Setup

Requirements:

- macOS with Xcode
- iOS 17 or later target
- An iPhone for real local-network testing
- Desktop Chrome or Edge for receiver testing

Build from the command line:

```sh
xcodebuild -project ios/EZCopy.xcodeproj -scheme EZCopy -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

For device builds, open `ios/EZCopy.xcodeproj` in Xcode and select your own
Signing & Capabilities team.

## Contribution Guidelines

- Keep the core workflow simple: select media, start receiver, open browser, download package.
- Avoid adding cloud upload, account systems, analytics, or external transfer services.
- Preserve the privacy expectation that media transfer happens locally.
- Prefer focused pull requests with a clear test note.
- Do not commit generated build output, DerivedData, personal signing settings, or local backups.

## Useful Test Cases

- Same Wi-Fi router, Chrome receiver.
- Same Wi-Fi router, Edge receiver.
- Computer connected to iPhone Personal Hotspot.
- Large video package generation and download.
- Wrong access code.
- Expired access code.
- iCloud-only original not downloaded locally.
