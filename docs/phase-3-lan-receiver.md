# Phase 3 LAN Receiver

Phase 3 adds the first real local-network connection path from a desktop browser to the iPhone app.

## Included

- iPhone-side TCP HTTP server on port `8080`.
- Start/stop controls in the iPhone app.
- Real local IP address detection.
- Session URL display in the app.
- Basic browser status page at `/`.
- Manifest JSON endpoint at `/manifest.json`.
- Selected media list rendered in the browser.

## Test Flow

1. Make sure the iPhone and computer are on the same Wi-Fi or LAN.
2. Open EZCopy on iPhone.
3. Select photos and videos if desired.
4. Tap `Start Receiver`.
5. Allow local network access if iOS asks.
6. Copy the displayed `http://<iphone-ip>:8080` URL.
7. Open that exact URL in desktop Chrome or Edge.

## Current Limit

This phase verifies browser-to-iPhone connectivity and selected media manifest output. Actual file chunk transfer is not implemented yet.

## Troubleshooting

- If the browser cannot connect, confirm the App shows `Server: Running`.
- Use the exact IP shown in the App, not a placeholder URL from older builds.
- Keep the iPhone unlocked and EZCopy in the foreground during this early test phase.
- Some Wi-Fi networks block device-to-device traffic. Personal hotspot or a home router usually works better than public/corporate Wi-Fi.
- If iOS asks for local network permission, choose Allow.
