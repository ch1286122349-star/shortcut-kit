#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ShortcutKit currently supports macOS only." >&2
  exit 1
fi
for command_name in awk cp mv shasum; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is missing: $command_name" >&2
    exit 1
  fi
done
echo "Preflight passed."
