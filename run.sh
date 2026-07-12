#!/usr/bin/env bash
# run.sh — Start the full stack: MCP proxy + Open WebUI (shared), then llama-server
# via the backend's own run.sh.
#   ./run.sh [vulkan|rocm]   # backend defaults to rocm
#   See run-tmux.sh          # run in tmux with mc
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
source .env

BACKEND="${1:-rocm}"

# Start MCP proxy — wraps stdio MCP servers as streamable HTTP on :8200 (for llama-server webui)
mcp-proxy --port 8200 --transport streamablehttp --named-server-config "$SCRIPT_DIR/mcp-config.json" &
MCP_PID=$!

# Start Open WebUI on port 3000, preconfigured to use llama-server
export DATA_DIR="$HOME/.open-webui"
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(cat "$DATA_DIR/.secret" 2>/dev/null || (mkdir -p "$DATA_DIR" && openssl rand -hex 32 | tee "$DATA_DIR/.secret"))}"
export ENABLE_OLLAMA_API=false
export OPENAI_API_KEYS="none"
if [[ "$BACKEND" == "vulkan" ]]; then
    export OPENAI_API_BASE_URLS="http://127.0.0.1:8080/v1;http://127.0.0.1:8081/v1"
else
    export OPENAI_API_BASE_URLS="http://127.0.0.1:8080/v1"
fi
open-webui serve --port 3000 &
OPENWEBUI_PID=$!

trap 'kill $MCP_PID $OPENWEBUI_PID 2>/dev/null' EXIT

# Hand off to the backend's own run.sh for the llama-server instance(s)
"$SCRIPT_DIR/$BACKEND/run.sh"
