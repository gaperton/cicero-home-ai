#!/usr/bin/env bash
# run.sh — Update llama.cpp & models, then start llama-server in router mode.
#   ./run.sh          # run directly
#   See run-tmux.sh   # run in tmux with mc
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

bash update.sh

# Start MCP proxy — wraps stdio MCP servers as streamable HTTP on :8200 (for llama-server webui)
mcp-proxy --port 8200 --transport streamablehttp --named-server-config "$SCRIPT_DIR/mcp-config.json" &
MCP_PID=$!

# Start Open WebUI on port 3000, preconfigured to use llama-server
export DATA_DIR="$HOME/.open-webui"
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(cat "$DATA_DIR/.secret" 2>/dev/null || (mkdir -p "$DATA_DIR" && openssl rand -hex 32 | tee "$DATA_DIR/.secret"))}"
export ENABLE_OLLAMA_API=false
export OPENAI_API_BASE_URLS="http://127.0.0.1:8080/v1"
export OPENAI_API_KEYS="none"
open-webui serve --port 3000 &
OPENWEBUI_PID=$!

trap 'kill $MCP_PID $OPENWEBUI_PID 2>/dev/null' EXIT


WEBUI_CONFIG_ARGS=()
if [[ -f "$SCRIPT_DIR/webui-config.json" ]]; then
    WEBUI_CONFIG_ARGS=(--webui-config-file "$SCRIPT_DIR/webui-config.json")
fi

./llama.cpp/llama-server \
    --host 0.0.0.0 --port 8080 \
    --models-preset models.ini \
    --models-max 1 \
    --webui-mcp-proxy \
    "${WEBUI_CONFIG_ARGS[@]}"
