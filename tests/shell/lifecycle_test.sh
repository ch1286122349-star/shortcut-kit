#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_area="$(mktemp -d)"
trap 'rm -rf "$test_area"' EXIT

existing="$test_area/existing"
mkdir -p "$existing"
cp -R "$project_root/tests/fixtures/hammerspoon/existing/." "$existing/"
"$project_root/install.sh" --root "$existing" --apply --skip-hammerspoon
"$project_root/install.sh" --root "$existing" --apply --skip-hammerspoon
if [[ "$(/usr/bin/awk '/shortcut-kit:begin/{count++} END{print count+0}' "$existing/init.lua")" -ne 1 ]]; then
  echo "repeated install duplicated the loader" >&2
  exit 1
fi
if ! rg -q 'user_existing_setting = true' "$existing/init.lua"; then
  echo "existing config was not preserved" >&2
  exit 1
fi

"$project_root/uninstall.sh" --root "$existing" --apply
if rg -q 'shortcut-kit:(begin|end)' "$existing/init.lua"; then
  echo "uninstall left loader markers" >&2
  exit 1
fi
if [[ -e "$existing/Spoons/ShortcutKit.spoon" ]]; then
  echo "uninstall left the Spoon" >&2
  exit 1
fi
"$project_root/restore.sh" --root "$existing" --apply
if ! rg -q 'shortcut-kit:begin' "$existing/init.lua"; then
  echo "restore did not recover the pre-uninstall install" >&2
  exit 1
fi

conflict="$test_area/conflict"
mkdir -p "$conflict"
cp -R "$project_root/tests/fixtures/hammerspoon/conflict/." "$conflict/"
before_hash="$(shasum -a 256 "$conflict/init.lua" | /usr/bin/awk '{print $1}')"
if "$project_root/install.sh" --root "$conflict" --apply --skip-hammerspoon; then
  echo "conflicting markers must fail closed" >&2
  exit 1
fi
after_hash="$(shasum -a 256 "$conflict/init.lua" | /usr/bin/awk '{print $1}')"
if [[ "$before_hash" != "$after_hash" ]]; then
  echo "failed conflict install changed init.lua" >&2
  exit 1
fi
if [[ -e "$conflict/Spoons" ]]; then
  echo "failed conflict install changed the fixture tree" >&2
  exit 1
fi

migrated="$test_area/migrated"
mkdir -p "$migrated"
cp -R "$project_root/tests/fixtures/hammerspoon/migrated/." "$migrated/"
"$project_root/install.sh" --root "$migrated" --apply --skip-hammerspoon
if [[ "$(/usr/bin/awk '/hs\.loadSpoon\("ShortcutKit"\)/{count++} END{print count+0}' "$migrated/init.lua")" -ne 1 ]]; then
  echo "update from the migration loader duplicated ShortcutKit" >&2
  exit 1
fi

echo "lifecycle_test: PASS"
