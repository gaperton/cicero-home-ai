#!/usr/bin/env bash
# run.sh — Update llama.cpp & models, then start llama-server.
#   ./run.sh          # run directly
#   See run-tmux.sh   # run in tmux with mc
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

bash update.sh

exec ./llama.cpp/llama-server --host 0.0.0.0 --models-preset models/presets.ini
