#!/bin/bash
# Run the GdUnit4 suite headless.
#
# GODOT_BIN can be overridden; the default is where the official macOS release
# lands. Homebrew will not install Godot on macOS 12 (no Command Line Tools),
# so this project uses the release zip from godotengine/godot directly.
set -euo pipefail
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [ ! -x "$GODOT_BIN" ]; then
  echo "Godot not found at $GODOT_BIN — set GODOT_BIN to your binary." >&2
  exit 1
fi

# Note: the runner is fail-fast. A failure stops the run, so the summary's
# test count will be lower than the total rather than showing every failure.
exec ./addons/gdUnit4/runtest.sh --add "${1:-test/}"
