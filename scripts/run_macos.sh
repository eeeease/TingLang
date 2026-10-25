#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/flutter_env.sh
bash scripts/bootstrap_macos.sh
exec "${FLUTTER_CMD[@]}" run -d macos "$@"
