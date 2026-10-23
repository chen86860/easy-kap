#!/usr/bin/env bash
# Builds a universal Release copy of Easy Kap and packages it as build/EasyKap.dmg with create-dmg
# (https://github.com/create-dmg/create-dmg): a laid-out window with the app beside an Applications shortcut.
# Used by the release workflow and for local testing. Needs `brew install xcodegen create-dmg`.
# The window background comes from Tools/dmg/, drawn by Tools/make-dmg-background.swift.
#
# With APPLE_SIGNING_IDENTITY set, the app and the disk image are signed with that Developer ID certificate
# (Tools/sign-app.sh); notarize afterwards with Tools/notarize-dmg.sh. Without it, the build stays ad-hoc signed.
#
#   Tools/make-dmg.sh           Use the version in project.yml
#   Tools/make-dmg.sh 0.2.0     Stamp that version into the app
set -euo pipefail

cd "$(dirname "$0")/.."

readonly version="${1:-}"
readonly derived_data="build/DerivedData"
readonly built_app="$derived_data/Build/Products/Release/EasyKap.app"
readonly dmg="build/EasyKap.dmg"

if ! command -v create-dmg >/dev/null; then
  echo "create-dmg is missing. Install it with: brew install create-dmg" >&2
  exit 69
fi

settings=(ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
# Sparkle orders updates by CFBundleVersion, so both versions take the release's number.
if [[ -n "$version" ]]; then settings+=(MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$version"); fi

echo "→ Building universal Release${version:+ $version}"
xcodegen generate --quiet
xcodebuild -quiet -project Kap.xcodeproj -scheme Kap -configuration Release \
  -derivedDataPath "$derived_data" -destination "generic/platform=macOS" "${settings[@]}" build

# create-dmg packs the whole source folder, so it gets a folder holding only the app.
staging="$(mktemp -d)"
work="$(mktemp -d)"
trap 'rm -rf "$staging" "$work"' EXIT
ditto "$built_app" "$staging/Easy Kap.app"
if [[ -n "${APPLE_SIGNING_IDENTITY:-}" ]]; then
  Tools/sign-app.sh "$staging/Easy Kap.app"
else
  echo "→ APPLE_SIGNING_IDENTITY is not set; keeping the ad-hoc signature"
fi

# A two-resolution TIFF keeps the background sharp on Retina displays.
tiffutil -cathidpicheck Tools/dmg/background.png Tools/dmg/background@2x.png -out "$work/background.tiff" 2>/dev/null

echo "→ Packaging $dmg"
rm -f "$dmg"
create-dmg \
  --volname "Easy Kap" \
  --volicon "Kap/Resources/AppIcon.icns" \
  --background "$work/background.tiff" \
  --window-pos 200 120 \
  --window-size 640 460 \
  --icon-size 112 \
  --text-size 13 \
  --icon "Easy Kap.app" 160 215 \
  --hide-extension "Easy Kap.app" \
  --app-drop-link 480 215 \
  --hdiutil-quiet \
  --hdiutil-retries 10 \
  "$dmg" "$staging" >/dev/null
if [[ -n "${APPLE_SIGNING_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$APPLE_SIGNING_IDENTITY" "$dmg"
fi
echo "→ $(du -h "$dmg" | cut -f1) $dmg ($(lipo -archs "$staging/Easy Kap.app/Contents/MacOS/EasyKap"))"
