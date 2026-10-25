# Sourced by the other scripts. Picks the Flutter SDK pinned in .fvmrc when fvm
# is installed; set FLUTTER_BIN=/path/to/flutter to override.
if [[ -n "${FLUTTER_BIN:-}" ]]; then
  FLUTTER_CMD=("$FLUTTER_BIN")
  DART_CMD=("$(dirname "$(command -v "$FLUTTER_BIN")")/dart")
elif command -v fvm >/dev/null 2>&1 && [[ -f .fvmrc ]]; then
  FLUTTER_CMD=(fvm flutter)
  DART_CMD=(fvm dart)
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER_CMD=(flutter)
  DART_CMD=(dart)
else
  FLUTTER_CMD=()
  DART_CMD=()
fi
