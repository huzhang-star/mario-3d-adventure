#!/bin/zsh

PROJECT_DIR="${0:A:h}"
GODOT_BIN="/Users/zoezhang/Downloads/Godot.app/Contents/MacOS/Godot"

if [[ -x "$GODOT_BIN" ]]; then
	exec "$GODOT_BIN" --path "$PROJECT_DIR"
fi

if command -v godot >/dev/null 2>&1; then
	exec godot --path "$PROJECT_DIR"
fi

if command -v godot4 >/dev/null 2>&1; then
	exec godot4 --path "$PROJECT_DIR"
fi

open -a Godot "$PROJECT_DIR/project.godot"
