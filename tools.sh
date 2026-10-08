#!/usr/bin/env bash
# Developer helper. Usage: ./tools.sh [import|test|run|web|windows]
# Set GODOT to your Godot 4.7 binary, or place it in tools/ (git-ignored).
set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-}"
if [[ -z "$GODOT" ]]; then
  GODOT="$(ls tools/Godot_v4*_console.exe tools/Godot_v4* 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "$GODOT" ]]; then
  GODOT="godot"
fi

case "${1:-test}" in
  import)  "$GODOT" --headless --path . --import ;;
  test)    "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
           "$GODOT" --headless --path . --script res://tests/run_tests.gd ;;
  run)     "$GODOT" --path . ;;
  web)     mkdir -p build/web && "$GODOT" --headless --path . --export-release "Web" build/web/index.html
           echo "Serve with: py -m http.server 8060 --directory build/web" ;;
  windows) mkdir -p build/windows && "$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/BopHouseSimulator.exe ;;
  *)       echo "Usage: $0 [import|test|run|web|windows]"; exit 1 ;;
esac
