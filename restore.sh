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
backup_dir="$(shortcut_kit_latest_backup "$target_root")" || { echo "No ShortcutKit backup found." >&2; exit 1; }
if [[ "$mode" == "dry-run" ]]; then echo "Would restore $backup_dir"; exit 0; fi

stage_dir="$(mktemp -d "$target_root/.shortcut-kit-restore.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
if [[ -f "$backup_dir/had-init" ]]; then cp -p "$backup_dir/init.lua" "$stage_dir/init.lua"; fi
if [[ -f "$backup_dir/had-spoon" ]]; then cp -R "$backup_dir/Spoons/ShortcutKit.spoon" "$stage_dir/ShortcutKit.spoon"; fi

if [[ -f "$backup_dir/had-init" ]]; then mv "$stage_dir/init.lua" "$target_root/init.lua"; else rm -f "$target_root/init.lua"; fi
if [[ -d "$target_root/Spoons/ShortcutKit.spoon" ]]; then
  old_dir="$stage_dir/current-ShortcutKit.spoon"
  mv "$target_root/Spoons/ShortcutKit.spoon" "$old_dir"
fi
if [[ -f "$backup_dir/had-spoon" ]]; then
  mkdir -p "$target_root/Spoons"
  mv "$stage_dir/ShortcutKit.spoon" "$target_root/Spoons/ShortcutKit.spoon"
fi
echo "Restored ShortcutKit backup: $backup_dir"
