# Local Receiver

Chrome may block `showDirectoryPicker()` on `http://<iphone-ip>:8080` because that page is not always treated as a secure browser context.

Use the local receiver page instead:

```text
web/receiver/standalone.html
```

## Test Flow

1. Open EZCopy on iPhone.
2. Select photos and videos.
3. Tap `Start Receiver`.
4. Copy the iPhone URL shown in the app, such as `http://192.168.1.12:8080`.
5. Open `web/receiver/standalone.html` in desktop Chrome.
6. Paste the iPhone URL into the input.
7. Click `Load Media`.
8. Click `Choose Folder and Copy`.

## Why This Exists

The iPhone app is still the media source. The local receiver page only gives Chrome a local, secure-enough page context so it can ask for folder write permission.

The transfer path remains local:

```text
iPhone Photos -> EZCopy iPhone app -> Wi-Fi LAN -> Chrome local receiver -> chosen folder
```

No cloud server is used.
