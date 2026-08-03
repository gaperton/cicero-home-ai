#!/usr/bin/env bash
# run.sh — Start the full stack: Open WebUI, then two llama-server instances
# (Vulkan backend), one pinned per GPU: port 8080 = Vulkan0, port 8081 = Vulkan1.
#   See run-tmux.sh   # run in tmux with mc
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
source .env

# Start Open WebUI on port 3000, preconfigured to use both llama-server instances
export DATA_DIR="$HOME/.open-webui"
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(cat "$DATA_DIR/.secret" 2>/dev/null || (mkdir -p "$DATA_DIR" && openssl rand -hex 32 | tee "$DATA_DIR/.secret"))}"
export ENABLE_OLLAMA_API=false
export OPENAI_API_KEYS="none;none"
export OPENAI_API_BASE_URLS="http://127.0.0.1:8080/v1"
open-webui serve --port 3000 &
PIDS=("$!")

trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT

# shellcheck disable=SC2086
"$SCRIPT_DIR/llama.cpp/llama-server" \
    $SERVER_FLAGS \
    --models-preset "$SCRIPT_DIR/models-0.ini" \
    --device Vulkan0 \
    --port 8080 &
PIDS+=("$!")

# shellcheck disable=SC2086
# --models-max 2 overrides SERVER_FLAGS' --models-max 1: this router keeps both
# gemma4-26b-a4b and the qwen3-reranker-0.6b reranking model resident at once
# for Hindsight, instead of evicting one to load the other on every call.
"$SCRIPT_DIR/llama.cpp/llama-server" \
    $SERVER_FLAGS \
    --models-max 2 \
    --models-preset "$SCRIPT_DIR/models-1.ini" \
    --device Vulkan1 \
    --port 8081 &
PIDS+=("$!")

wait -n
