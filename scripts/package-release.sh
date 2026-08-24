#!/bin/bash
set -euo pipefail

version="${1:-}"
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Usage: package-release.sh vX.Y.Z" >&2; exit 2; }
project_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$project_root/dist"
archive="$project_root/dist/shortcut-kit-$version.zip"
checksum="$archive.sha256"
rm -f "$archive" "$checksum"
(
  cd "$project_root"
  /usr/bin/zip -q -r "$archive" . \
    -x '.git/*' '.worktrees/*' 'build/*' 'dist/*' '.DS_Store'
)
archive_hash="$(shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')"
printf '%s  %s\n' "$archive_hash" "$(basename "$archive")" > "$checksum"
echo "Created $archive"
echo "Created $checksum"
