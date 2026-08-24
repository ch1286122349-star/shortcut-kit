#!/bin/bash
set -euo pipefail

action="${1:-}"
init_path="${2:-}"
[[ "$action" == "add" || "$action" == "remove" ]] || { echo "Usage: patch-init.sh add|remove <init.lua>" >&2; exit 2; }
[[ -n "$init_path" ]] || { echo "init.lua path is required" >&2; exit 2; }

begin_count=0
end_count=0
if [[ -f "$init_path" ]]; then
  begin_count="$(/usr/bin/awk '/^[[:space:]]*-- shortcut-kit:begin[[:space:]]*$/{count++} END{print count+0}' "$init_path")"
  end_count="$(/usr/bin/awk '/^[[:space:]]*-- shortcut-kit:end[[:space:]]*$/{count++} END{print count+0}' "$init_path")"
fi
if [[ "$begin_count" -gt 1 || "$end_count" -gt 1 || "$begin_count" -ne "$end_count" ]]; then
  echo "Refusing ambiguous ShortcutKit markers in $init_path" >&2
  exit 1
fi

parent_dir="$(dirname "$init_path")"
mkdir -p "$parent_dir"
temp_path="$(mktemp "$parent_dir/.shortcut-kit-init.XXXXXX")"
trap 'rm -f "$temp_path"' EXIT

if [[ -f "$init_path" ]]; then
  /usr/bin/awk '
    /^[[:space:]]*-- shortcut-kit:begin[[:space:]]*$/ { skipping=1; next }
    /^[[:space:]]*-- shortcut-kit:end[[:space:]]*$/ { skipping=0; next }
    !skipping { print }
  ' "$init_path" > "$temp_path"
fi

if [[ "$action" == "add" ]]; then
  {
    printf '\n-- shortcut-kit:begin\n'
    printf 'hs.loadSpoon("ShortcutKit")\n'
    printf 'spoon.ShortcutKit:start()\n'
    printf 'shortcutKitStatus = function() return spoon.ShortcutKit:status() end\n'
    printf '%s\n' '-- shortcut-kit:end'
  } >> "$temp_path"
fi
chmod 600 "$temp_path"
mv "$temp_path" "$init_path"
trap - EXIT
