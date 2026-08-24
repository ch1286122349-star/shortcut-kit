#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
for test_file in "$project_root"/tests/shell/*_test.sh; do
  [[ -f "$test_file" ]] || continue
  bash "$test_file"
done
