#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd -P)"
binary="$project_root/ShortcutKit.spoon/bin/local-ocr"

"$project_root/scripts/build-ocr.sh"
architecture_info="$(lipo -info "$binary")"
if [[ "$architecture_info" != *"x86_64"* || "$architecture_info" != *"arm64"* ]]; then
  printf 'expected universal binary, got: %s\n' "$architecture_info" >&2
  exit 1
fi
"$binary" --self-test >/dev/null

printf 'build_ocr_test: PASS\n'
