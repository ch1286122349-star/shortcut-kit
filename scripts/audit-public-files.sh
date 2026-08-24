#!/bin/bash
set -euo pipefail

tree="${1:-.}"
[[ -d "$tree" ]] || { echo "Audit tree is not a directory." >&2; exit 2; }

fail_rule() {
  echo "Public audit failed: $1" >&2
  exit 1
}

private_pattern='/Users/'"sheldon"
private_key_pattern='BEGIN (RSA |OPENSSH |EC )?PRIVATE'" KEY"
github_token_pattern='ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]+'
generic_secret_pattern='(api[_-]?key|access[_-]?token|client[_-]?secret)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_./+-]{16,}'

while IFS= read -r -d '' file_path; do
  relative="${file_path#"$tree"/}"
  case "$relative" in
    .git|.git/*|.worktrees/*|build/*|dist/*) continue ;;
  esac
  case "$relative" in
    *.log|*/logs/*|*/backups/*|*.bak) fail_rule "runtime-artifact" ;;
  esac
  if LC_ALL=C /usr/bin/grep -aEq "$private_pattern" "$file_path"; then fail_rule "private-home-path"; fi
  if LC_ALL=C /usr/bin/grep -aEq "$private_key_pattern" "$file_path"; then fail_rule "private-key"; fi
  if LC_ALL=C /usr/bin/grep -aEq "$github_token_pattern" "$file_path"; then fail_rule "github-token"; fi
  if LC_ALL=C /usr/bin/grep -aEiq "$generic_secret_pattern" "$file_path"; then fail_rule "embedded-secret"; fi

  file_kind="$(/usr/bin/file -b "$file_path")"
  if [[ "$file_kind" == *"Mach-O"* && "$relative" != "ShortcutKit.spoon/bin/local-ocr" ]]; then
    fail_rule "unapproved-binary"
  fi
done < <(find "$tree" -type f -print0)

echo "Public audit passed."
