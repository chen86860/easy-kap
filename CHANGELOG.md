# Changelog

All notable changes to Easy Kap are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

Every release needs a section here before its tag is pushed: the release workflow fails without one, and the section becomes both the GitHub release notes and the notes Sparkle shows in the update window.

## [Unreleased]

### Fixed

- The menu bar icon's menu opens in full below the icon. It used to open collapsed and had to be scrolled.
- Stopping a recording with both menu bar buttons, Easy Kap's and the system's, no longer shows "Failed due to an invalid parameter".

## [0.1.3] - 2026-10-23

### Added

- Easy Kap is signed with a Developer ID and notarized by Apple, so macOS opens it without asking you to allow it in System Settings.

### Fixed

- Easy Kap 0.1.2 quit as soon as it opened. macOS refused to load the update framework into an ad-hoc signed app running with the hardened runtime.

### Changed

- The disk image window is taller, so the install instructions sit clear of the window's bottom edge.

## [0.1.2] - 2026-10-23

### Added

- Automatic updates. Easy Kap checks for new versions in the background and installs them when you agree. **Check for Updates…** is in the menu bar menu, and Settings has a switch to turn automatic checks off.
- Settings shows the installed version.

## [0.1.1] - 2026-10-23

The first public release of Easy Kap, a native rewrite of Kap.

### Added

- Record any area of a screen with ScreenCaptureKit: drag a selection, lock an aspect ratio, type an exact size, or pick a whole screen or an app's window. The last recorded area is remembered.
- Pause and resume a recording from the menu bar.
- Record system audio, the microphone, or both, and show the cursor and click highlights.
- An editor that loops the recording, with a hover trim bar, frame previews, resizing and frame rate options.
- Export to GIF, MP4 (H.264), MP4 (HEVC) and APNG, and save to disk, copy to the clipboard, or open with another app.
- A universal disk image for Apple Silicon and Intel, built by GitHub Actions. It opens to a window with the app, an Applications shortcut and install instructions.
- While recording, the menu bar shows a red Kap ring and the time recorded. Stopping from the macOS screen recording indicator also saves the recording.

## [0.1.0] - 2026-10-23

Tagged but never released: the build crashed the Swift 6.3 compiler in Xcode 26.6. Version 0.1.1 contains the fix.

[Unreleased]: https://github.com/chen86860/easy-kap/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/chen86860/easy-kap/releases/tag/v0.1.3
[0.1.2]: https://github.com/chen86860/easy-kap/releases/tag/v0.1.2
[0.1.1]: https://github.com/chen86860/easy-kap/releases/tag/v0.1.1
[0.1.0]: https://github.com/chen86860/easy-kap/tree/v0.1.0
