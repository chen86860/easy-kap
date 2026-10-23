# Easy Kap

A native macOS screen recorder in Swift, inspired by [Kap](https://github.com/wulkano/Kap). Built for Apple Silicon, with no Electron and no bundled ffmpeg.

## Inspired by Kap

Easy Kap started from a love of [Kap](https://getkap.co) by [Wulkano](https://wulkano.com), which has not been updated for Apple Silicon. It keeps Kap's workflow and look — the menu bar recorder, the area picker, the hover-to-trim editor, the gradient ring — and rebuilds them on current system frameworks. It is an independent project, not affiliated with or endorsed by Wulkano. Kap's menu bar icon is reused under its MIT license; see [LICENSE](LICENSE).

## Features

- **Capture:** ScreenCaptureKit (`SCRecordingOutput`) records straight to H.264, with the cursor and click highlighting drawn by the system, optional system audio and microphone, pause and resume, and Easy Kap's own windows left out of the recording.
- **Area picker:** drag to select an area, lock an aspect ratio, pick a whole screen or an app's window, or enter an exact size. The last recorded area is remembered.
- **Editor:** the video loops; hovering shows trim controls with frame previews. Export to GIF, MP4 (H.264), MP4 (HEVC) or APNG through AVFoundation/VideoToolbox and ImageIO, with resizing and frame rate options. Save to disk, copy to the clipboard, or open with another app.
- **System integration:** a global shortcut, Liquid Glass on macOS 26+, and light and dark appearance.

Requires macOS 15+.

## Develop

```sh
brew install xcodegen   # the .xcodeproj is generated from project.yml
make build              # Debug build
make run                # build and launch
make test               # Swift Testing suite
make lint               # SwiftLint (version pinned in mise.toml)
make release            # Universal Release build
```

Builds are ad-hoc signed. macOS ties the Screen Recording permission to the signature, so you may need to allow the app again after rebuilding.

The app icon is drawn by `Tools/render-icon.swift` (`swift Tools/render-icon.swift icon.png`); build the iconset from that PNG with `sips` and `iconutil`.

## License

[MIT](LICENSE)
