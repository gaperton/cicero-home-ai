#!/usr/bin/env bash
# gpu-0-1/webui.sh — Open WebUI alone, pointed at the combined router on :8081.
# Run by cicero-vulkan0.service. Foreground; exits if it dies.
#
# In the combined topology the router serves both cards from one port, so this
# unit no longer starts a llama-server of its own — it is Open WebUI only.
# Note that :8081 exposes all three models, so the WebUI model list now includes
# `llm` and `reranker` alongside the chat model; hide them in WebUI's settings
# if that is noise.
set -euo pipefail

GPU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$GPU_DIR")"
cd "$REPO"

export DATA_DIR="$HOME/.open-webui"
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(cat "$DATA_DIR/.secret" 2>/dev/null || (mkdir -p "$DATA_DIR" && openssl rand -hex 32 | tee "$DATA_DIR/.secret"))}"
export ENABLE_OLLAMA_API=false
export OPENAI_API_KEYS="none"
export OPENAI_API_BASE_URLS="http://127.0.0.1:8081/v1"

exec open-webui serve --port 3000
