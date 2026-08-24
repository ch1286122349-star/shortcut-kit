#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$project_root/scripts/lib/common.sh"

target_root="$HOME/.hammerspoon"
mode=""
skip_hammerspoon=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) target_root="$2"; shift 2 ;;
    --dry-run) mode="dry-run"; shift ;;
    --apply) mode="apply"; shift ;;
    --skip-hammerspoon) skip_hammerspoon=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$mode" ]] || { echo "Choose --dry-run or --apply" >&2; exit 2; }
shortcut_kit_validate_root "$target_root"

if [[ "$mode" == "dry-run" ]]; then
  echo "Would install ShortcutKit into $target_root"
  echo "Would preserve init.lua, add one marked loader, and create a rollback backup."
  [[ "$skip_hammerspoon" == true ]] || echo "Would install Hammerspoon if it is missing."
  exit 0
fi

precheck_dir="$(mktemp -d)"
trap 'rm -rf "$precheck_dir"' EXIT
if [[ -f "$target_root/init.lua" ]]; then cp -p "$target_root/init.lua" "$precheck_dir/init.lua"; else : > "$precheck_dir/init.lua"; fi
"$project_root/scripts/patch-init.sh" add "$precheck_dir/init.lua"

[[ "$skip_hammerspoon" == true ]] || "$project_root/scripts/install-hammerspoon.sh"
mkdir -p "$target_root/Spoons"
stage_dir="$(mktemp -d "$target_root/.shortcut-kit-stage.XXXXXX")"
cp -R "$project_root/ShortcutKit.spoon" "$stage_dir/ShortcutKit.spoon"
cp -p "$precheck_dir/init.lua" "$stage_dir/init.lua"
chmod +x "$stage_dir/ShortcutKit.spoon/bin/local-ocr"
backup_dir="$("$project_root/scripts/backup-config.sh" create "$target_root")"

old_spoon="$stage_dir/old-ShortcutKit.spoon"
if [[ -d "$target_root/Spoons/ShortcutKit.spoon" ]]; then
  mv "$target_root/Spoons/ShortcutKit.spoon" "$old_spoon"
fi
mv "$stage_dir/ShortcutKit.spoon" "$target_root/Spoons/ShortcutKit.spoon"
mv "$stage_dir/init.lua" "$target_root/init.lua"
"$project_root/scripts/verify-install.sh" --root "$target_root" --offline
echo "Backup: $backup_dir"
echo "ShortcutKit installed. Open Hammerspoon and grant Accessibility/Screen Recording when macOS asks."
