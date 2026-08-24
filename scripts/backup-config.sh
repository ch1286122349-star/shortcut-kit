#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

[[ "${1:-}" == "create" && -n "${2:-}" ]] || { echo "Usage: backup-config.sh create <root>" >&2; exit 2; }
target_root="$2"
shortcut_kit_validate_root "$target_root"
mkdir -p "$target_root/.shortcut-kit-backups"
backup_dir="$target_root/.shortcut-kit-backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup_dir"

if [[ -f "$target_root/init.lua" ]]; then
  cp -p "$target_root/init.lua" "$backup_dir/init.lua"
  : > "$backup_dir/had-init"
fi
if [[ -d "$target_root/Spoons/ShortcutKit.spoon" ]]; then
  mkdir -p "$backup_dir/Spoons"
  cp -R "$target_root/Spoons/ShortcutKit.spoon" "$backup_dir/Spoons/"
  : > "$backup_dir/had-spoon"
fi
echo "$backup_dir"
