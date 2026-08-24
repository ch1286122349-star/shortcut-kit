#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=hammerspoon-release.env
source "$script_dir/hammerspoon-release.env"

if [[ -d "/Applications/Hammerspoon.app" || -d "$HOME/Applications/Hammerspoon.app" ]]; then
  echo "Hammerspoon is already installed."
  exit 0
fi

if command -v brew >/dev/null 2>&1; then
  brew install --cask hammerspoon
  exit 0
fi

download_dir="$(mktemp -d)"
trap 'rm -rf "$download_dir"' EXIT
archive="$download_dir/Hammerspoon.zip"
/usr/bin/curl --fail --location --silent --show-error "$HAMMERSPOON_URL" --output "$archive"
actual_sha="$(shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')"
if [[ "$actual_sha" != "$HAMMERSPOON_SHA256" ]]; then
  echo "Hammerspoon archive checksum mismatch." >&2
  exit 1
fi
/usr/bin/ditto -x -k "$archive" "$download_dir/unpacked"
mkdir -p "$HOME/Applications"
/usr/bin/ditto "$download_dir/unpacked/Hammerspoon.app" "$HOME/Applications/Hammerspoon.app"
echo "Installed Hammerspoon $HAMMERSPOON_VERSION in $HOME/Applications."
