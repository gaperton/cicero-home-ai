#!/usr/bin/env bash
# run.sh — Update llama.cpp & models, then start llama-server in router mode.
#   ./run.sh [vulkan|rocm]   # backend defaults to vulkan
#   See run-tmux.sh          # run in tmux with mc
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
source .env

BACKEND="${1:-vulkan}"
LLAMA_DIR="$SCRIPT_DIR/llama-$BACKEND"
SERVER_FLAGS_BACKEND="SERVER_FLAGS_${BACKEND^^}"

# RADV_DEBUG=nocompute suppresses a spurious AMD Vulkan warning, only needed for Vulkan
[[ "$BACKEND" == "vulkan" ]] && export RADV_DEBUG=nocompute

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

WEBUI_CONFIG_ARGS=()
if [[ -f "$SCRIPT_DIR/webui-config.json" ]]; then
    WEBUI_CONFIG_ARGS=(--webui-config-file "$SCRIPT_DIR/webui-config.json")
fi

if [[ "$BACKEND" == "vulkan" ]]; then
    # GPU 0 — port 8080 (background)
    # shellcheck disable=SC2086
    GGML_VK_VISIBLE_DEVICES=0 "$LLAMA_DIR/llama-server" \
        $SERVER_FLAGS_COMMON \
        ${!SERVER_FLAGS_BACKEND} \
        --port 8080 \
        "${WEBUI_CONFIG_ARGS[@]}" &
    SERVER0_PID=$!
    trap 'kill $MCP_PID $OPENWEBUI_PID $SERVER0_PID 2>/dev/null' EXIT

    # GPU 1 — port 8081 (foreground)
    # shellcheck disable=SC2086
    GGML_VK_VISIBLE_DEVICES=1 "$LLAMA_DIR/llama-server" \
        $SERVER_FLAGS_COMMON \
        ${!SERVER_FLAGS_BACKEND} \
        --port 8081 \
        "${WEBUI_CONFIG_ARGS[@]}"
else
    # shellcheck disable=SC2086
    "$LLAMA_DIR/llama-server" \
        $SERVER_FLAGS_COMMON \
        ${!SERVER_FLAGS_BACKEND} \
        --port 8080 \
        "${WEBUI_CONFIG_ARGS[@]}"
fi
