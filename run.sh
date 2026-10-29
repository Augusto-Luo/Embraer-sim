#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -n "${GODOT_BIN:-}" ]]; then
  exec "$GODOT_BIN" --path "$SCRIPT_DIR" "$@"
fi
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$SCRIPT_DIR" "$@"
fi
if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  exec "/Applications/Godot.app/Contents/MacOS/Godot" --path "$SCRIPT_DIR" "$@"
fi
echo "Godot 4.7+ is required. Set GODOT_BIN or add godot to PATH." >&2
exit 1
