#!/usr/bin/env bash
# Notarizes and staples build/EasyKap.dmg so it opens without a Gatekeeper warning.
# Needs APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD and APPLE_TEAM_ID, or APPLE_NOTARY_KEYCHAIN_PROFILE for a profile
# saved with `xcrun notarytool store-credentials`. The DMG must already be signed by Tools/make-dmg.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

readonly dmg="${1:-build/EasyKap.dmg}"
[[ -f "$dmg" ]] || { echo "No disk image at $dmg" >&2; exit 66; }

if [[ -n "${APPLE_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  credentials=(--keychain-profile "$APPLE_NOTARY_KEYCHAIN_PROFILE")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  credentials=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
else
  echo "Set APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD and APPLE_TEAM_ID, or APPLE_NOTARY_KEYCHAIN_PROFILE." >&2
  exit 64
fi

echo "→ Notarizing $dmg"
xcrun notarytool submit "$dmg" "${credentials[@]}" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose "$dmg"
