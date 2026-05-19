# Phase 1 Foundation

Phase 1 creates the first usable EZCopy development foundation.

## Included

- iOS SwiftUI app project named EZCopy.
- Shared transfer manifest JSON schema.
- Swift manifest model.
- TypeScript declaration for browser-side manifest usage.
- Static browser receiver project.
- Chrome and Edge support detection.
- Mock transfer flow using the File System Access API.
- Mock report, manifest, and checksum file output.

## Run the iOS App

Open the project in Xcode:

```sh
open ios/EZCopy.xcodeproj
```

Or build for the iOS simulator:

```sh
xcodebuild -project ios/EZCopy.xcodeproj -scheme EZCopy -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Run the Browser Receiver

From the receiver folder:

```sh
npm run dev
```

Then open:

```text
http://localhost:5173
```

Use desktop Chrome or Edge. The mock flow asks for a destination folder, creates an `EZCopy_Mock_2026-05-19_1530` folder, writes placeholder media files, and outputs report files.

## Next Phase

Phase 2 should replace the disabled app button with real Photos permission and media picking.
