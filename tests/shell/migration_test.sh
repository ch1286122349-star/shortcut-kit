#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_area="$(mktemp -d)"
trap 'chmod -R u+w "$test_area" 2>/dev/null || true; rm -rf "$test_area"' EXIT

matching="$test_area/matching"
mismatch="$test_area/mismatch"
rollback="$test_area/rollback"
mkdir -p "$matching" "$mismatch" "$rollback"
cp -R "$project_root/tests/fixtures/source-machine/matching/." "$matching/"
cp -R "$project_root/tests/fixtures/source-machine/mismatch/." "$mismatch/"

"$project_root/scripts/migrate-source-machine.sh" \
  --source "$matching" \
  --fingerprints "$project_root/tests/fixtures/source-machine/fingerprints.txt" \
  --rollback-root "$rollback" \
  --apply --offline
if ! rg -q '^hs\.loadSpoon\("ShortcutKit"\)$' "$matching/init.lua"; then
  echo "matching source was not migrated to the minimal loader" >&2
  exit 1
fi
if [[ ! -f "$matching/Spoons/ShortcutKit.spoon/init.lua" ]]; then
  echo "matching source did not receive the Spoon" >&2
  exit 1
fi

mismatch_before="$(shasum -a 256 "$mismatch/init.lua" | /usr/bin/awk '{print $1}')"
if "$project_root/scripts/migrate-source-machine.sh" \
  --source "$mismatch" \
  --fingerprints "$project_root/tests/fixtures/source-machine/fingerprints.txt" \
  --rollback-root "$rollback" \
  --apply --offline; then
  echo "fingerprint mismatch must fail closed" >&2
  exit 1
fi
mismatch_after="$(shasum -a 256 "$mismatch/init.lua" | /usr/bin/awk '{print $1}')"
[[ "$mismatch_before" == "$mismatch_after" ]] || { echo "mismatch source changed" >&2; exit 1; }

rollback_source="$test_area/forced-rollback"
cp -R "$project_root/tests/fixtures/source-machine/matching/." "$rollback_source/"
before_tree="$(find "$rollback_source" -type f -print0 | sort -z | xargs -0 shasum -a 256)"
if SHORTCUT_KIT_FORCE_VERIFY_FAILURE=1 "$project_root/scripts/migrate-source-machine.sh" \
  --source "$rollback_source" \
  --fingerprints "$project_root/tests/fixtures/source-machine/fingerprints.txt" \
  --rollback-root "$rollback" \
  --apply --offline; then
  echo "forced verification failure must fail" >&2
  exit 1
fi
after_tree="$(find "$rollback_source" -type f -print0 | sort -z | xargs -0 shasum -a 256)"
[[ "$before_tree" == "$after_tree" ]] || { echo "forced failure did not restore the source" >&2; exit 1; }

echo "migration_test: PASS"
