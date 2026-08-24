#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

./scripts/package-app.sh v0.2.0

APP="build/ShortcutKit.app"
test -x "$APP/Contents/MacOS/ShortcutKitApp"
test -f "$APP/Contents/Resources/ShortcutKit.spoon/init.lua"
test -x "$APP/Contents/Resources/scripts/install.sh"
test -x "$APP/Contents/Resources/scripts/verify-install.sh"
test -f "$APP/Contents/Resources/shortcut-catalog.json"
test -f "$APP/Contents/Resources/AppIcon.icns"
test -f "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP/Contents/Info.plist" | rg -q '^true$'
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" | rg -q '^0\.2\.0$'
"$APP/Contents/MacOS/ShortcutKitApp" --self-test | rg -q 'ShortcutKitApp self-test: PASS'

echo "app_package_test: PASS"
