#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd -P)"
filter="${1:-}"
hs_cli="${HS_CLI:-/opt/homebrew/bin/hs}"

if [[ ! -x "$hs_cli" ]]; then
  printf 'Hammerspoon CLI not found: %s\n' "$hs_cli" >&2
  exit 1
fi

found=0
for test_file in "$project_root"/tests/lua/*_spec.lua; do
  [[ -f "$test_file" ]] || continue
  if [[ -n "$filter" && "$(basename "$test_file")" != *"$filter"* ]]; then
    continue
  fi
  found=1
  escaped_root="${project_root//\\/\\\\}"
  escaped_root="${escaped_root//\"/\\\"}"
  escaped_test="${test_file//\\/\\\\}"
  escaped_test="${escaped_test//\"/\\\"}"
  test_result="$("$hs_cli" -c "SHORTCUT_KIT_TEST_ROOT=\"$escaped_root\"; local ok,err=pcall(dofile,\"$escaped_test\"); return ok and \"PASS\" or \"FAIL:\"..tostring(err)" | tail -n 1)"
  if [[ "$test_result" != "PASS" ]]; then
    printf '%s: %s\n' "$(basename "$test_file")" "$test_result" >&2
    exit 1
  fi
  printf '%s: PASS\n' "$(basename "$test_file")"
done

if [[ "$found" -eq 0 ]]; then
  printf 'No Lua tests matched filter: %s\n' "$filter" >&2
  exit 1
fi
