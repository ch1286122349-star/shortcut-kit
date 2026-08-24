#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd -P)"
source_file="$project_root/ShortcutKit.spoon/bin/local-ocr.swift"
build_dir="$project_root/build"
mkdir -p "$build_dir"

build_arch() {
  local arch="$1"
  xcrun swiftc -O -target "$arch-apple-macos13.0" "$source_file" \
    -o "$build_dir/local-ocr-$arch"
}

native_arch="$(uname -m)"
build_arch "$native_arch"

other_arch="x86_64"
[[ "$native_arch" == "x86_64" ]] && other_arch="arm64"
if build_arch "$other_arch" 2>"$build_dir/$other_arch-build.log"; then
  lipo -create "$build_dir/local-ocr-arm64" "$build_dir/local-ocr-x86_64" \
    -output "$build_dir/local-ocr-universal"
else
  rm -f "$build_dir/local-ocr-$other_arch"
fi

(
  cd "$build_dir"
  shasum -a 256 local-ocr-* > checksums.txt
)

install_source="$build_dir/local-ocr-$native_arch"
if [[ -x "$build_dir/local-ocr-universal" ]]; then
  install_source="$build_dir/local-ocr-universal"
fi
cp "$install_source" "$project_root/ShortcutKit.spoon/bin/local-ocr"
chmod +x "$project_root/ShortcutKit.spoon/bin/local-ocr"
