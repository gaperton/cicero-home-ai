#!/usr/bin/env bash
# gpu-0/run.sh — Open WebUI + llama-server on ROCm0:8080.
# Run by cicero-vulkan0.service. Foreground; exits if either child dies.
set -euo pipefail

GPU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$GPU_DIR")"
cd "$REPO"          # preset `model =` paths are relative to the repo root
source .env

PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT

export DATA_DIR="$HOME/.open-webui"
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(cat "$DATA_DIR/.secret" 2>/dev/null || (mkdir -p "$DATA_DIR" && openssl rand -hex 32 | tee "$DATA_DIR/.secret"))}"
export ENABLE_OLLAMA_API=false
export OPENAI_API_KEYS="none;none"
export OPENAI_API_BASE_URLS="http://127.0.0.1:8080/v1"
open-webui serve --port 3000 &
PIDS+=("$!")

# active.ini is a symlink ./switch repoints.
PRESET="${PRESET:-$GPU_DIR/active.ini}"
[ -e "$PRESET" ] || { echo "gpu-0/run.sh: missing preset $PRESET" >&2; exit 1; }

# --models-max cannot go inside the ini: the router reads it before presets load.
# One model at a time: the chat models and the batch-* judge/answer
# models are used in separate phases and cannot co-reside anyway.
MAX=1
echo "gpu-0: $(basename "$(readlink -f "$PRESET")") (--models-max $MAX)"

# shellcheck disable=SC2086
"$REPO/llama.cpp/llama-server" \
    $SERVER_FLAGS \
    --models-max "$MAX" \
    --models-preset "$PRESET" \
    --device ROCm0 \
    --port 8080 &
PIDS+=("$!")

wait -n
