#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || { echo 'Usage: bash scripts/package-macos.sh network_lookup|process_manager OUTPUT_DIRECTORY' >&2; exit 2; }
case "$1" in network_lookup|process_manager) ;; *) echo 'Unknown app.' >&2; exit 2 ;; esac
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS packaging requires ditto on macOS.' >&2; exit 1; }
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
release_dir="$project_root/apps/$1/build/macos/Build/Products/Release"
shopt -s nullglob
bundles=("$release_dir"/*.app)
[[ ${#bundles[@]} -eq 1 ]] || { echo "Expected exactly one .app in $release_dir; build the app first." >&2; exit 1; }
[[ -d "${bundles[0]}/Contents/MacOS" && -d "${bundles[0]}/Contents/Frameworks" ]] || { echo 'Incomplete macOS bundle.' >&2; exit 1; }
mkdir -p -- "$2"
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${bundles[0]}/Contents/Info.plist")
architectures=$(lipo -archs "${bundles[0]}/Contents/MacOS/$executable")
if [[ "$architectures" == *arm64* && "$architectures" == *x86_64* ]]; then
  architecture=universal
elif [[ "$architectures" == arm64 || "$architectures" == x86_64 ]]; then
  architecture="$architectures"
else
  echo "Unexpected application architectures: $architectures" >&2
  exit 1
fi
archive="$2/hudu-$1-macos-$architecture.zip"
[[ ! -e "$archive" ]] || { echo "Refusing to overwrite $archive; choose a fresh output directory." >&2; exit 1; }
# Preserve framework symlinks, executable permissions, and the enclosing .app.
ditto -c -k --sequesterRsrc --keepParent "${bundles[0]}" "$archive"
unzip -tq "$archive"
echo "$archive"
