# Easy Kap

A native macOS screen recorder (Swift 6, SwiftUI and AppKit, ScreenCaptureKit), plus its website in `website/`.

## Build and check

```sh
make build && make lint && make test        # the app
cd website && pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

The Xcode project is generated from `project.yml` with XcodeGen; never edit `Kap.xcodeproj`.

## Releasing

Every release must have notes in `CHANGELOG.md`:

1. Move the `## [Unreleased]` entries into a new `## [x.y.z] - YYYY-MM-DD` section, written for users, and update the compare links at the bottom.
2. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` to the same `x.y.z`.
3. Commit, then push the tag `vx.y.z`.

The release workflow fails when the changelog section is missing. It publishes `EasyKap.dmg` and a Sparkle `appcast.xml` signed with the `SPARKLE_PRIVATE_KEY` secret; the app checks `releases/latest/download/appcast.xml`, so keep both asset names. The same key lives in the login Keychain under the Sparkle account `easy-kap`. Losing it means existing installs can no longer update.
