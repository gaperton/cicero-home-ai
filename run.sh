#!/usr/bin/env bash
# run.sh — Update llama.cpp & models, then start llama-server in router mode.
#   ./run.sh          # run directly
#   See run-tmux.sh   # run in tmux with mc
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

bash update.sh

# Start MCP proxy (brave search → HTTP on :8200)
mcpo --port 8200 --config "$SCRIPT_DIR/mcp-config.json" &
MCPO_PID=$!
trap 'kill $MCPO_PID 2>/dev/null' EXIT


WEBUI_CONFIG_ARGS=()
if [[ -f "$SCRIPT_DIR/webui-config.json" ]]; then
    WEBUI_CONFIG_ARGS=(--webui-config-file "$SCRIPT_DIR/webui-config.json")
fi

./llama.cpp/llama-server \
    --host 0.0.0.0 --port 8080 \
    --models-preset models.ini \
    --models-max 1 \
    "${WEBUI_CONFIG_ARGS[@]}"
