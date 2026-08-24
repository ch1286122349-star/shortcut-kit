#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

printf 'path=/Users/%s/private\n' 'sheldon' > "$fixture/leak.txt"
if "$project_root/scripts/audit-public-files.sh" "$fixture" > "$fixture/output.txt" 2>&1; then
  echo "private path leak must fail" >&2
  exit 1
fi
if ! rg -q 'private-home-path' "$fixture/output.txt"; then
  echo "audit did not report the redacted rule name" >&2
  exit 1
fi
if rg -q '/Users/' "$fixture/output.txt"; then
  echo "audit output exposed the private path" >&2
  exit 1
fi

rm -f "$fixture/leak.txt" "$fixture/output.txt"
printf '{"clipboard":"private"}\n' > "$fixture/session.diagnostics.json"
if "$project_root/scripts/audit-public-files.sh" "$fixture" > "$fixture/output.txt" 2>&1; then
  echo "raw app diagnostics must fail" >&2
  exit 1
fi
if ! rg -q 'runtime-artifact' "$fixture/output.txt"; then
  echo "audit did not report the diagnostics rule" >&2
  exit 1
fi
if rg -q 'private' "$fixture/output.txt"; then
  echo "audit output exposed diagnostics content" >&2
  exit 1
fi

echo "public_audit_test: PASS"
