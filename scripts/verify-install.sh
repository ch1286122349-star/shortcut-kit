#!/bin/bash
set -euo pipefail

target_root=""
offline=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) target_root="$2"; shift 2 ;;
    --offline) offline=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$target_root" ]] || { echo "--root is required" >&2; exit 2; }
[[ -f "$target_root/init.lua" ]] || { echo "init.lua is missing" >&2; exit 1; }
[[ -f "$target_root/Spoons/ShortcutKit.spoon/init.lua" ]] || { echo "ShortcutKit.spoon is missing" >&2; exit 1; }
[[ -x "$target_root/Spoons/ShortcutKit.spoon/bin/local-ocr" ]] || { echo "local OCR binary is missing or not executable" >&2; exit 1; }
[[ "$(/usr/bin/awk '/shortcut-kit:begin/{count++} END{print count+0}' "$target_root/init.lua")" -eq 1 ]] || exit 1
[[ "$(/usr/bin/awk '/shortcut-kit:end/{count++} END{print count+0}' "$target_root/init.lua")" -eq 1 ]] || exit 1
if [[ "$offline" == false ]] && command -v hs >/dev/null 2>&1; then
  hs -c 'hs.reload()' >/dev/null
fi
echo "ShortcutKit install verified."
