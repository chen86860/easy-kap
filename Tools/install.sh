#!/usr/bin/env bash
# Builds Easy Kap and installs it into /Applications for local testing, replacing any copy already installed.
#
#   Tools/install.sh                      Build, replace the installed copy, and launch it
#   Tools/install.sh --reset-permissions  Same, and forget the Screen Recording and Microphone grants
#   Tools/install.sh uninstall            Remove the installed app
#   Tools/install.sh uninstall --purge    Also remove its settings, cached recordings, and permission grants
#
# Only Easy Kap (io.github.chen86860.EasyKap) is touched. Removed apps go to the Trash, and exported recordings
# in ~/Movies/Kaptures are never removed.
set -euo pipefail

cd "$(dirname "$0")/.."

readonly bundle_id="io.github.chen86860.EasyKap"
readonly process_name="EasyKap"
readonly destination="/Applications/Easy Kap.app"
readonly derived_data="build/DerivedData"
readonly built_app="$derived_data/Build/Products/Release/EasyKap.app"
readonly lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

command=install
reset_permissions=false
purge=false
for argument in "$@"; do
  case "$argument" in
    install | uninstall) command="$argument" ;;
    --reset-permissions) reset_permissions=true ;;
    --purge) purge=true ;;
    -h | --help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $argument" >&2; exit 64 ;;
  esac
done

quit_running_app() {
  pgrep -x "$process_name" >/dev/null || return 0
  echo "→ Quitting Easy Kap"
  osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true
  for _ in {1..20}; do
    pgrep -x "$process_name" >/dev/null || return 0
    sleep 0.25
  done
  pkill -x "$process_name" || true
}

remove_installed_app() {
  local app
  for app in "$destination" "$HOME/Applications/Easy Kap.app" "/Applications/EasyKap.app"; do
    if [[ -d "$app" ]]; then
      trash "$app"
      echo "→ Moved $app to the Trash"
    fi
  done
}

reset_permission_grants() {
  # Ad-hoc signatures change with every build, which leaves earlier grants pointing at a stale signature.
  tccutil reset ScreenCapture "$bundle_id" >/dev/null 2>&1 || true
  tccutil reset Microphone "$bundle_id" >/dev/null 2>&1 || true
  echo "→ Reset Screen Recording and Microphone permissions"
}

remove_app_data() {
  defaults delete "$bundle_id" >/dev/null 2>&1 || true
  rm -rf "$HOME/Library/Caches/$bundle_id"
  echo "→ Removed settings and cached recordings"
}

build() {
  echo "→ Building (Release)"
  xcodegen generate --quiet
  xcodebuild -quiet -project Kap.xcodeproj -scheme Kap -configuration Release \
    -derivedDataPath "$derived_data" -destination "platform=macOS,arch=$(uname -m)" build
}

case "$command" in
  install)
    build
    quit_running_app
    remove_installed_app
    ditto "$built_app" "$destination"
    "$lsregister" -f "$destination"
    echo "→ Installed $destination"
    if $reset_permissions; then reset_permission_grants; fi
    # Launch Services can briefly refuse to open an app that just quit and was replaced, so retry once.
    open "$destination" 2>/dev/null || { sleep 1; open "$destination"; }
    ;;
  uninstall)
    quit_running_app
    remove_installed_app
    if $purge; then
      remove_app_data
      reset_permission_grants
    fi
    ;;
esac
