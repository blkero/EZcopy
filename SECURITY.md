# Security Policy

## Supported Versions

EZCopy is pre-release software. Security fixes should target the current
development branch until a stable release policy is defined.

## Security Model

EZCopy is designed for trusted local-network transfer:

- Media files are served from the iPhone to a desktop browser over the local network.
- The app does not intentionally upload selected media to the internet.
- Each receiver session uses a short access code.
- Receiver sessions expire automatically after 10 minutes.
- iCloud-only originals are not automatically downloaded by EZCopy.

## Important Limitations

- The current receiver uses plain HTTP on the local network, not HTTPS.
- Access codes reduce accidental access but are not a substitute for using a trusted network.
- Public Wi-Fi, hotel Wi-Fi, and enterprise Wi-Fi can block device discovery or expose devices to more peers.
- MD5 output is for transfer integrity checking only, not cryptographic security.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately before opening a public issue.

If this repository is published on GitHub, use GitHub's private vulnerability
reporting feature if enabled. Otherwise contact the maintainer through the
preferred contact method listed in the repository profile.
