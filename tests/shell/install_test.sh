#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

if ! "$project_root/install.sh" --root "$test_root" --dry-run --skip-hammerspoon; then
  echo "dry-run failed" >&2
  exit 1
fi
if [[ -e "$test_root/init.lua" || -e "$test_root/Spoons/ShortcutKit.spoon" ]]; then
  echo "dry-run changed the fixture" >&2
  exit 1
fi

"$project_root/install.sh" --root "$test_root" --apply --skip-hammerspoon
if [[ ! -f "$test_root/Spoons/ShortcutKit.spoon/init.lua" ]]; then
  echo "Spoon was not installed" >&2
  exit 1
fi
if [[ "$(/usr/bin/awk '/shortcut-kit:begin/{count++} END{print count+0}' "$test_root/init.lua")" -ne 1 ]]; then
  echo "loader marker was not added exactly once" >&2
  exit 1
fi
if ! rg -q 'spoon\.ShortcutKit:startFromAppConfig\(\)' "$test_root/init.lua"; then
  echo "App-aware loader was not installed" >&2
  exit 1
fi
if ! rg -q 'shortcutKitAppStatus' "$test_root/init.lua"; then
  echo "App status endpoint was not installed" >&2
  exit 1
fi
"$project_root/scripts/verify-install.sh" --root "$test_root" --offline

echo "install_test: PASS"
