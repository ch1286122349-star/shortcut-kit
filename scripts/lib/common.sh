#!/bin/bash
set -euo pipefail

shortcut_kit_project_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

shortcut_kit_validate_root() {
  local target_root="$1"
  if [[ -z "$target_root" || "$target_root" == "/" || "$target_root" == "$HOME" ]]; then
    echo "Refusing unsafe Hammerspoon root: $target_root" >&2
    return 1
  fi
}

shortcut_kit_latest_backup() {
  local target_root="$1"
  local backup_root="$target_root/.shortcut-kit-backups"
  [[ -d "$backup_root" ]] || return 1
  /bin/ls -1dt "$backup_root"/* 2>/dev/null | /usr/bin/head -n 1
}
