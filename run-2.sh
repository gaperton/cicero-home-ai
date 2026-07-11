#!/usr/bin/env bash
# run-2.sh — Start llama-server on ROCm using both GPUs (split-mode=layer, models-2.ini).
#   ./run-2.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
source .env

LLAMA_DIR="$SCRIPT_DIR/llama-rocm"

# Start MCP proxy — wraps stdio MCP servers as streamable HTTP on :8200 (for llama-server webui)
mcp-proxy --port 8200 --transport streamablehttp --named-server-config "$SCRIPT_DIR/mcp-config.json" &
MCP_PID=$!

# Start Open WebUI on port 3000, preconfigured to use llama-server
export DATA_DIR="$HOME/.open-webui"
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(cat "$DATA_DIR/.secret" 2>/dev/null || (mkdir -p "$DATA_DIR" && openssl rand -hex 32 | tee "$DATA_DIR/.secret"))}"
export ENABLE_OLLAMA_API=false
export OPENAI_API_KEYS="none"
export OPENAI_API_BASE_URLS="http://127.0.0.1:8080/v1"

# Both GPUs visible — split-mode=layer in models-2.ini spreads layers across them
# shellcheck disable=SC2086
HIP_VISIBLE_DEVICES=0,1 "$LLAMA_DIR/llama-server" \
    $SERVER_FLAGS_COMMON \
    $SERVER_FLAGS_ROCM \
    --models-preset models-2.ini \
    --port 8080 \
    "${WEBUI_CONFIG_ARGS[@]}"
