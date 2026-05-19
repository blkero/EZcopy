# EZCopy

EZCopy is an iPhone-first local media copy tool for creators.

The product helps users select photos and videos from the iPhone Photos library, then copy the original media files to a computer over the local network. The receiving side runs in desktop Chrome or Edge, opens the iPhone LAN address, verifies the short access code, downloads one ZIP transfer package, and includes a manifest, report, and optional MD5 checksum output.

## MVP Scope

- iPhone app for selecting photos and videos from the Photos library.
- Local network transfer between iPhone and computer.
- Browser receiver for desktop Chrome and Edge only.
- ZIP package download through the browser.
- Original media transfer without compression or transcoding where possible.
- Optional source-side MD5 checksum generation.
- Transfer report, manifest, and checksum output.

## Non Goals

- Safari and Firefox support.
- Android support.
- Cloud transfer.
- Professional film-industry DIT workflows.
- Desktop native receiver app.
- RAW, ProRAW, Live Photo, and advanced media grouping in the first MVP.

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
