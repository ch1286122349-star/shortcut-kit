#!/bin/bash
set -euo pipefail

version="${1:-}"
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Usage: package-dmg.sh vX.Y.Z" >&2; exit 2; }
project_root="$(cd "$(dirname "$0")/.." && pwd)"
app="$project_root/build/ShortcutKit.app"
dist="$project_root/dist"
dmg="$dist/ShortcutKit-$version.dmg"
zip="$dist/ShortcutKit-$version.zip"

"$project_root/scripts/package-app.sh" "$version"
mkdir -p "$dist"
rm -f "$dmg" "$zip" "$dmg.sha256" "$zip.sha256"
/usr/bin/hdiutil create -quiet -fs HFS+ -volname "ShortcutKit" -srcfolder "$app" "$dmg"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

for artifact in "$dmg" "$zip"; do
  hash="$(shasum -a 256 "$artifact" | /usr/bin/awk '{print $1}')"
  printf '%s  %s\n' "$hash" "$(basename "$artifact")" > "$artifact.sha256"
  (cd "$dist" && shasum -a 256 -c "$(basename "$artifact").sha256")
done

echo "Created $dmg"
echo "Created $zip"
