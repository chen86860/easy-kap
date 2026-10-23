<p align="center">
  <img src=".github/media/banner.png" alt="Easy Kap: a native macOS screen recorder, inspired by Kap and rebuilt for Apple Silicon" width="100%">
</p>

<p align="center">
  <a href="https://github.com/chen86860/easy-kap/releases/latest"><img src="https://img.shields.io/github/v/release/chen86860/easy-kap?label=release&color=6458f5" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-15%2B-141829" alt="macOS 15 or later">
  <img src="https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-universal-12d6be" alt="Universal binary">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-5a6377" alt="MIT License"></a>
</p>

<p align="center">
  <a href="https://github.com/chen86860/easy-kap/releases/latest/download/EasyKap.dmg"><b>Download EasyKap.dmg</b></a>
  &nbsp;·&nbsp;
  <a href="https://easy-kap.emmmm.dev"><b>easy-kap.emmmm.dev</b></a>
</p>

# Easy Kap

A native macOS screen recorder in Swift, inspired by [Kap](https://github.com/wulkano/Kap). Built for Apple Silicon and Intel, with no Electron and no bundled ffmpeg.

## Inspired by Kap

Easy Kap started from a love of [Kap](https://getkap.co) by [Wulkano](https://wulkano.com), which hasn't had a release since 2022. It keeps Kap's workflow and look — the menu bar recorder, the area picker, the hover-to-trim editor, the gradient ring — and rebuilds them on current system frameworks. It is an independent project, not affiliated with or endorsed by Wulkano. Kap's menu bar icon is reused under its MIT license; see [LICENSE](LICENSE).

## Features

- **Capture:** ScreenCaptureKit (`SCRecordingOutput`) records straight to H.264, with the cursor and click highlighting drawn by the system, optional system audio and microphone, pause and resume, and Easy Kap's own windows left out of the recording.
- **Area picker:** drag to select an area, lock an aspect ratio, pick a whole screen or an app's window, or enter an exact size. The last recorded area is remembered.
- **Editor:** the video loops; hovering shows trim controls with frame previews. Export to GIF, MP4 (H.264), MP4 (HEVC) or APNG through AVFoundation/VideoToolbox and ImageIO, with resizing and frame rate options. Save to disk, copy to the clipboard, or open with another app.
- **System integration:** a global shortcut, Liquid Glass on macOS 26+, and light and dark appearance.

Requires macOS 15+.

## Install

1. Download **EasyKap.dmg** from the [latest release](https://github.com/chen86860/easy-kap/releases/latest).
2. Open it and drag Easy Kap into Applications.
3. Open Easy Kap. It isn't notarized by Apple yet, so macOS blocks the first launch: go to **System Settings → Privacy & Security** and click **Open Anyway**.
4. Record once and allow Screen Recording when macOS asks, then reopen Easy Kap.

## Develop

```sh
brew install xcodegen create-dmg   # the .xcodeproj is generated from project.yml; create-dmg packs the DMG
make build              # Debug build
make run                # build and launch
make test               # Swift Testing suite
make lint               # SwiftLint (version pinned in mise.toml)
make release            # Universal Release build
make dmg                # Universal Release build packaged as build/EasyKap.dmg
make install            # build, replace /Applications/Easy Kap.app, and launch it
make uninstall          # remove the installed app
```

`Tools/install.sh` also takes `--reset-permissions` (forget the Screen Recording and Microphone grants after installing) and `uninstall --purge` (also remove settings and cached recordings). It only touches Easy Kap, moves removed apps to the Trash, and never deletes exported recordings.

Builds are ad-hoc signed. macOS ties the Screen Recording permission to the signature, so you may need to allow the app again after rebuilding.

The disk image window background is drawn by `Tools/make-dmg-background.swift` into `Tools/dmg/`; rerun it after changing the layout in `Tools/make-dmg.sh`.

The app icon is drawn by `Tools/render-icon.swift` (`swift Tools/render-icon.swift icon.png`); build the iconset from that PNG with `sips` and `iconutil`.

## Releases

Pushing a tag such as `v0.1.1` runs [the release workflow](.github/workflows/release.yml) on GitHub Actions: it stamps the version into the app, builds `EasyKap.dmg` with `Tools/make-dmg.sh`, and publishes it as a release. The asset name stays `EasyKap.dmg`, so `releases/latest/download/EasyKap.dmg` always points at the newest build.

## Website

The product site, [easy-kap.emmmm.dev](https://easy-kap.emmmm.dev), lives in [`website/`](website): React, Vite, TanStack Router, Tailwind CSS and shadcn/ui, served by Cloudflare Workers.

```sh
cd website
pnpm install
pnpm dev                # local server
pnpm typecheck && pnpm lint && pnpm test && pnpm build
pnpm run deploy         # build and deploy with Wrangler
```

## License

[MIT](LICENSE)
