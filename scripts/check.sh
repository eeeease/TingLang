#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/flutter_env.sh
python3 -m unittest discover -s tools/tests -v
if [[ ${#FLUTTER_CMD[@]} -eq 0 ]]; then
  echo 'Flutter is not installed. Python delivery checks ran; Dart/Flutter checks did NOT run.' >&2
  exit 2
fi
"${FLUTTER_CMD[@]}" --version
"${FLUTTER_CMD[@]}" pub get
"${FLUTTER_CMD[@]}" analyze --no-fatal-infos
"${FLUTTER_CMD[@]}" test
# Workspace packages with their own tests (pure Dart first).
(cd packages/tinglang_platform_interface && "${DART_CMD[@]}" test)
# The cloud API contract (api/) and its pure-Dart client.
(cd packages/tinglang_api && "${DART_CMD[@]}" run tool/validate_api.dart && "${DART_CMD[@]}" test)
# Cloud speech adapters (loopback servers only).
(cd packages/tinglang_cloud_asr && "${DART_CMD[@]}" test)
(cd packages/tinglang_ui && "${FLUTTER_CMD[@]}" test)
(cd packages/tinglang_native && "${FLUTTER_CMD[@]}" test)
(cd packages/tinglang_native_macos && "${FLUTTER_CMD[@]}" test)
if [[ "${1:-}" == --build ]]; then
  bash scripts/bootstrap_macos.sh
  "${FLUTTER_CMD[@]}" build macos --release
  APP=build/macos/Build/Products/Release/Tinglang.app
  # The audio tap silently records zeros without this literal key.
  printf 'NSAudioCaptureUsageDescription: '
  plutil -extract NSAudioCaptureUsageDescription raw "$APP/Contents/Info.plist"
  plutil -extract NSMicrophoneUsageDescription raw "$APP/Contents/Info.plist" >/dev/null
  test -f "$APP/Contents/Resources/zh-Hans.lproj/InfoPlist.strings"
  codesign --verify --strict "$APP"
  codesign -dv --verbose=2 "$APP" 2>&1 | grep -E '^(Identifier|TeamIdentifier|Signature|CodeDirectory)' || true
  # Real macOS run: Pigeon probe + shell, using a temporary library folder.
  # One file per run: a second app launch in the same run fails on macOS.
  # (integration_test/screenshots_test.dart is run by hand, see its header.)
  "${FLUTTER_CMD[@]}" test integration_test/app_test.dart -d macos
fi
