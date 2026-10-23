#!/usr/bin/env bash
# Re-signs an Easy Kap build with a Developer ID certificate and the hardened runtime, inside out:
# Sparkle's nested helpers first, then the app. Called by Tools/make-dmg.sh when APPLE_SIGNING_IDENTITY is set.
#
#   APPLE_SIGNING_IDENTITY="Developer ID Application: Name (TEAMID)" Tools/sign-app.sh "path/Easy Kap.app"
set -euo pipefail

cd "$(dirname "$0")/.."

readonly app="${1:?Usage: Tools/sign-app.sh <path to Easy Kap.app>}"
readonly identity="${APPLE_SIGNING_IDENTITY:?APPLE_SIGNING_IDENTITY is required}"
readonly entitlements="Kap/Kap.entitlements"

[[ -d "$app" ]] || { echo "No app at $app" >&2; exit 66; }
[[ -f "$entitlements" ]] || { echo "$entitlements is missing. Run xcodegen generate first." >&2; exit 66; }

sign=(codesign --force --timestamp --options runtime --sign "$identity")

# Sparkle ships its own helpers (Autoupdate, Updater.app and XPC services); each needs the same identity.
"${sign[@]}" --deep "$app/Contents/Frameworks/Sparkle.framework"
"${sign[@]}" --entitlements "$entitlements" "$app"

codesign --verify --deep --strict --verbose=2 "$app"
echo "→ Signed $app as $identity"
