#!/bin/bash
set -euo pipefail

version="${1:-}"
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Usage: package-app.sh vX.Y.Z" >&2; exit 2; }
short_version="${version#v}"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$project_root/build/ShortcutKit.app"
contents="$app_dir/Contents"

cd "$project_root"
./scripts/build-ocr.sh
swift build -c release --package-path app

rm -rf "$app_dir"
mkdir -p "$contents/MacOS" "$contents/Resources/scripts"
/usr/bin/ditto "$project_root/app/.build/release/ShortcutKitApp" "$contents/MacOS/ShortcutKitApp"
chmod 755 "$contents/MacOS/ShortcutKitApp"
/usr/bin/strip -S "$contents/MacOS/ShortcutKitApp"
/usr/bin/ditto "$project_root/app/Resources/Info.plist" "$contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $short_version" "$contents/Info.plist"
/usr/bin/ditto "$project_root/app/Resources/AppIcon.icns" "$contents/Resources/AppIcon.icns"
/usr/bin/ditto "$project_root/app/Sources/ShortcutKitApp/Resources/shortcut-catalog.json" "$contents/Resources/shortcut-catalog.json"
/usr/bin/ditto "$project_root/ShortcutKit.spoon" "$contents/Resources/ShortcutKit.spoon"

for file in install.sh update.sh uninstall.sh restore.sh; do
  /usr/bin/ditto "$project_root/$file" "$contents/Resources/$file"
  chmod 755 "$contents/Resources/$file"
done
/usr/bin/ditto "$project_root/scripts" "$contents/Resources/scripts"
/usr/bin/ditto "$project_root/app/Resources/scripts/install.sh" "$contents/Resources/scripts/install.sh"
find "$contents/Resources/scripts" -type f -name '*.sh' -exec chmod 755 {} +

echo "Created $app_dir"
