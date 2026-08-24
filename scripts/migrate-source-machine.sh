#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

source_root=""
fingerprints="$script_dir/source-fingerprints.txt"
rollback_root=""
mode=""
offline=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) source_root="$2"; shift 2 ;;
    --fingerprints) fingerprints="$2"; shift 2 ;;
    --rollback-root) rollback_root="$2"; shift 2 ;;
    --apply) mode="apply"; shift ;;
    --dry-run) mode="dry-run"; shift ;;
    --offline) offline=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$source_root" ]] || { echo "--source is required" >&2; exit 2; }
[[ -n "$mode" ]] || { echo "Choose --dry-run or --apply" >&2; exit 2; }
shortcut_kit_validate_root "$source_root"
[[ -f "$fingerprints" ]] || { echo "Fingerprint file is missing: $fingerprints" >&2; exit 1; }

while IFS='  ' read -r expected relative_path; do
  relative_path="${relative_path# }"
  [[ -n "$expected" && -n "$relative_path" ]] || continue
  target="$source_root/$relative_path"
  [[ -f "$target" ]] || { echo "Migration source is missing: $relative_path" >&2; exit 1; }
  actual="$(shasum -a 256 "$target" | /usr/bin/awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "Migration fingerprint mismatch: $relative_path" >&2
    exit 1
  fi
done < "$fingerprints"

if [[ "$mode" == "dry-run" ]]; then
  echo "All source fingerprints match. Migration would proceed."
  exit 0
fi

if [[ -z "$rollback_root" ]]; then rollback_root="$source_root/.shortcut-kit-migration-backups"; fi
mkdir -p "$rollback_root"
backup_dir="$rollback_root/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup_dir"

while IFS= read -r -d '' entry; do
  cp -R "$entry" "$backup_dir/"
done < <(find "$source_root" -mindepth 1 -maxdepth 1 \
  ! -name '.shortcut-kit-migration-backups' -print0)

restore_backup() {
  local failed_dir
  failed_dir="$(mktemp -d "${TMPDIR:-/tmp}/shortcut-kit-failed.XXXXXX")"
  while IFS= read -r -d '' entry; do mv "$entry" "$failed_dir/"; done < <(
    find "$source_root" -mindepth 1 -maxdepth 1 ! -name '.shortcut-kit-migration-backups' -print0
  )
  cp -R "$backup_dir/." "$source_root/"
  rm -rf "$failed_dir"
}

mkdir -p "$source_root/Spoons"
stage_dir="$(mktemp -d "$source_root/.shortcut-kit-migrate.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
cp -R "$project_root/ShortcutKit.spoon" "$stage_dir/ShortcutKit.spoon"
chmod +x "$stage_dir/ShortcutKit.spoon/bin/local-ocr"
if [[ -d "$source_root/Spoons/ShortcutKit.spoon" ]]; then
  mv "$source_root/Spoons/ShortcutKit.spoon" "$stage_dir/old-ShortcutKit.spoon"
fi
mv "$stage_dir/ShortcutKit.spoon" "$source_root/Spoons/ShortcutKit.spoon"

init_stage="$(mktemp "$source_root/.shortcut-kit-init.XXXXXX")"
{
  printf '%s\n' 'hs.loadSpoon("ShortcutKit")'
  printf '%s\n' 'spoon.ShortcutKit:start()'
  printf '%s\n' 'shortcutKitStatus = function() return spoon.ShortcutKit:status() end'
} > "$init_stage"
chmod 600 "$init_stage"
mv "$init_stage" "$source_root/init.lua"

verified=true
if [[ "${SHORTCUT_KIT_FORCE_VERIFY_FAILURE:-0}" == "1" ]]; then
  verified=false
elif ! "$script_dir/verify-install.sh" --root "$source_root" --offline >/dev/null; then
  verified=false
elif [[ "$offline" == false ]]; then
  if ! command -v hs >/dev/null 2>&1; then
    verified=false
  else
    hs -c 'hs.reload()' >/dev/null || verified=false
    /bin/sleep 1
    status="$(hs -c 'local s=shortcutKitStatus and shortcutKitStatus(); return s and tostring(s.ok) or "missing"' 2>/dev/null || true)"
    [[ "$status" == *"true"* ]] || verified=false
  fi
fi

if [[ "$verified" != true ]]; then
  restore_backup
  echo "Migration verification failed; the original configuration was restored." >&2
  exit 1
fi

chmod -R a-w "$backup_dir"
echo "ShortcutKit migration completed. Rollback: $backup_dir"
