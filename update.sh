#!/usr/bin/env bash
# update.sh — Pull latest llama.cpp, rebuild, and refresh models from HuggingFace.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="$HOME/.local/bin:$PATH"

"$SCRIPT_DIR/stop.sh" || true

"$SCRIPT_DIR/build.sh"

# Download/update models from HuggingFace (skips unchanged files)
"$SCRIPT_DIR/models/update.sh"

"$SCRIPT_DIR/start.sh" || true
