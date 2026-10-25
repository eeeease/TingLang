#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/flutter_env.sh
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This script prepares the macOS app. Run it on your MacBook.' >&2
  exit 1
fi
if [[ ${#FLUTTER_CMD[@]} -eq 0 ]]; then
  echo 'Missing Flutter. Install fvm (recommended) or Flutter; see README.md.' >&2
  exit 1
fi
for tool in python3 xcodebuild; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing $tool. Install full Xcode and Python 3; see README.md." >&2
    exit 1
  fi
done
# Flutter 3.47 uses Swift Package Manager; CocoaPods is only needed for
# plugins that still ship podspecs only.
command -v pod >/dev/null 2>&1 || echo 'Note: CocoaPods not found; fine unless a plugin requires it.' >&2
if ! xcodebuild -version >/dev/null 2>&1; then
  echo 'Xcode is not ready. Open Xcode once, complete setup and run flutter doctor -v.' >&2
  exit 1
fi
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else "Python 3.10+ is required.")'
"${FLUTTER_CMD[@]}" --version
"${FLUTTER_CMD[@]}" config --enable-macos-desktop
# Generate the platform runner in a temporary project, never over app source.
if [[ ! -f macos/Runner.xcodeproj/project.pbxproj ]]; then
  if [[ -e macos ]]; then
    echo 'A partial macos/ directory exists. Move it aside after inspecting it; it will not be overwritten.' >&2
    exit 1
  fi
  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tinglang-runner.XXXXXX")"
  trap 'rm -rf "$TEMP_DIR"' EXIT
  "${FLUTTER_CMD[@]}" create --platforms=macos --project-name tinglang --org dev.eeeease --no-pub "$TEMP_DIR/tinglang"
  python3 - "$TEMP_DIR/tinglang/macos" "$ROOT/macos" <<'PY'
import shutil, sys
shutil.copytree(sys.argv[1], sys.argv[2], ignore=shutil.ignore_patterns('ephemeral', '.symlinks', 'xcuserdata'))
PY
fi
"${FLUTTER_CMD[@]}" pub get
python3 scripts/configure_macos.py
# Generated runner is reproducible; library.json, media and recordings are NOT in this repo.
printf '\nTinglang is ready for: %s run -d macos\n' "${FLUTTER_CMD[*]}"
