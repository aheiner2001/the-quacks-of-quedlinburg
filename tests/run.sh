#!/usr/bin/env bash
set -euo pipefail

GODOT="${GODOT:-/opt/homebrew/bin/godot}"

"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://tests/run_all_tests.gd
