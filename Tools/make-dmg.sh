#!/usr/bin/env bash
# Builds a universal Release copy of Easy Kap and packages it as build/EasyKap.dmg,
# with an Applications shortcut to drag it onto. Used by the release workflow and for local testing.
#
#   Tools/make-dmg.sh           Use the version in project.yml
#   Tools/make-dmg.sh 0.2.0     Stamp that version into the app
set -euo pipefail

cd "$(dirname "$0")/.."

readonly version="${1:-}"
readonly derived_data="build/DerivedData"
readonly built_app="$derived_data/Build/Products/Release/EasyKap.app"
readonly dmg="build/EasyKap.dmg"

settings=(ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
if [[ -n "$version" ]]; then settings+=(MARKETING_VERSION="$version"); fi

echo "→ Building universal Release${version:+ $version}"
xcodegen generate --quiet
xcodebuild -quiet -project Kap.xcodeproj -scheme Kap -configuration Release \
  -derivedDataPath "$derived_data" -destination "generic/platform=macOS" "${settings[@]}" build

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$built_app" "$staging/Easy Kap.app"
ln -s /Applications "$staging/Applications"

echo "→ Packaging $dmg"
rm -f "$dmg"
hdiutil create -quiet -volname "Easy Kap" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"
echo "→ $(du -h "$dmg" | cut -f1) $dmg ($(lipo -archs "$staging/Easy Kap.app/Contents/MacOS/EasyKap"))"
