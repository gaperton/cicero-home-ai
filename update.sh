#!/usr/bin/env bash
# update.sh — Pull latest llama.cpp, rebuild backend(s), and refresh models from HuggingFace.
#   ./update.sh           # rebuild both
#   ./update.sh vulkan    # rebuild vulkan only
#   ./update.sh rocm      # rebuild rocm only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="$HOME/.local/bin:$PATH"

BACKEND="${1:-both}"

"$SCRIPT_DIR/stop.sh" || true

[[ "$BACKEND" == "vulkan" || "$BACKEND" == "both" ]] && "$SCRIPT_DIR/vulkan/build.sh"
[[ "$BACKEND" == "rocm"   || "$BACKEND" == "both" ]] && "$SCRIPT_DIR/rocm/build.sh"

# Download/update models from HuggingFace (skips unchanged files)
"$SCRIPT_DIR/models/update.sh"

"$SCRIPT_DIR/start.sh" || true
