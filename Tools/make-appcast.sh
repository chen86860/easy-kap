#!/usr/bin/env bash
# Writes the Sparkle appcast and the release notes for one version, from build/EasyKap.dmg and CHANGELOG.md.
#
#   Tools/make-appcast.sh 0.1.2
#
# Outputs build/appcast.xml (the update feed the app reads) and build/release-notes.md (the GitHub release notes).
# Fails when CHANGELOG.md has no section for the version, so every release has notes.
#
# The DMG is signed with the EdDSA key from the SPARKLE_PRIVATE_KEY environment variable when it is set (CI),
# otherwise with the "easy-kap" key in the login Keychain (created by `generate_keys --account easy-kap`).
# Sparkle's tools are downloaded into build/sparkle on first use.
set -euo pipefail

cd "$(dirname "$0")/.."

readonly version="${1:?Usage: Tools/make-appcast.sh <version>}"
readonly sparkle_version="2.10.0" # keep in step with the Sparkle package in project.yml
readonly repository="https://github.com/chen86860/easy-kap"
readonly dmg="build/EasyKap.dmg"
readonly tools="build/sparkle/bin"

[[ -f "$dmg" ]] || { echo "$dmg is missing. Build it first with Tools/make-dmg.sh $version" >&2; exit 66; }

# The changelog section for this version, without its heading.
notes="$(awk -v version="$version" '
  $0 ~ "^## \\[" version "\\]" { found = 1; next }
  found && /^## \[/ { exit }
  found && /^\[[^]]+\]: / { exit }
  found { print }
' CHANGELOG.md | sed -e '/./,$!d')"
if [[ -z "${notes//[$'\t\r\n ']/}" ]]; then
  echo "CHANGELOG.md has no notes for $version. Add a \"## [$version] - $(date +%F)\" section before releasing." >&2
  exit 65
fi
printf '%s\n' "$notes" > build/release-notes.md

if [[ ! -x "$tools/sign_update" ]]; then
  echo "→ Downloading Sparkle $sparkle_version tools"
  mkdir -p build/sparkle
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$sparkle_version/Sparkle-$sparkle_version.tar.xz" | tar -xJ -C build/sparkle
fi

echo "→ Signing $dmg"
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  key_file="$(mktemp)"
  trap 'rm -f "$key_file"' EXIT
  printf '%s' "$SPARKLE_PRIVATE_KEY" > "$key_file"
  signature="$("$tools/sign_update" --ed-key-file "$key_file" "$dmg")"
else
  signature="$("$tools/sign_update" --account easy-kap "$dmg")"
fi

# Sparkle shows the description as HTML in its update window. The Python is single-quoted on purpose.
# shellcheck disable=SC2016
notes_html="$(printf '%s\n' "$notes" | python3 -c '
import html, re, sys
out, in_list = [], False
def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    return re.sub(r"`(.+?)`", r"<code>\1</code>", text)
for line in sys.stdin.read().splitlines():
    if line.startswith("- "):
        if not in_list:
            out.append("<ul>"); in_list = True
        out.append(f"<li>{inline(line[2:])}</li>")
        continue
    if in_list:
        out.append("</ul>"); in_list = False
    if line.startswith("### "):
        out.append(f"<h3>{inline(line[4:])}</h3>")
    elif line.strip():
        out.append(f"<p>{inline(line)}</p>")
if in_list:
    out.append("</ul>")
print("\n".join(out))
')"

cat > build/appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Easy Kap</title>
    <link>$repository</link>
    <item>
      <title>Easy Kap $version</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$version</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>$repository/blob/main/CHANGELOG.md</sparkle:fullReleaseNotesLink>
      <description><![CDATA[
$notes_html
      ]]></description>
      <enclosure url="$repository/releases/download/v$version/EasyKap.dmg" $signature type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF
xmllint --noout build/appcast.xml
echo "→ build/appcast.xml and build/release-notes.md for $version"
