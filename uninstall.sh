#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$project_root/scripts/lib/common.sh"
target_root="$HOME/.hammerspoon"
mode=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) target_root="$2"; shift 2 ;;
    --dry-run) mode="dry-run"; shift ;;
    --apply) mode="apply"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$mode" ]] || { echo "Choose --dry-run or --apply" >&2; exit 2; }
shortcut_kit_validate_root "$target_root"
if [[ "$mode" == "dry-run" ]]; then echo "Would remove only ShortcutKit from $target_root"; exit 0; fi

backup_dir="$("$project_root/scripts/backup-config.sh" create "$target_root")"
if [[ -f "$target_root/init.lua" ]]; then "$project_root/scripts/patch-init.sh" remove "$target_root/init.lua"; fi
if [[ -d "$target_root/Spoons/ShortcutKit.spoon" ]]; then
  trash_dir="$(mktemp -d "$target_root/.shortcut-kit-remove.XXXXXX")"
  mv "$target_root/Spoons/ShortcutKit.spoon" "$trash_dir/"
  rm -rf "$trash_dir"
fi
echo "ShortcutKit uninstalled. Backup: $backup_dir"
