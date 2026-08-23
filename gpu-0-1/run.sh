#!/usr/bin/env bash
# gpu-0-1/run.sh — Open WebUI plus one llama-server router across both cards.
# Run by cicero-home-ai.service. Foreground; exits if either child dies.
#
# Port 8081, not 8080, on purpose: the section names [llm] and [reranker] are
# the ids Hindsight resolves, so keeping its port too means no HINDSIGHT_API_*
# env change. Open WebUI listens on :3000 and points at the same router.
set -euo pipefail

GPU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$GPU_DIR")"
cd "$REPO"          # preset `model =` paths are relative to the repo root
source .env

PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT

PRESET="${PRESET:-$GPU_DIR/active.ini}"
[ -e "$PRESET" ] || { echo "gpu-0-1/run.sh: missing preset $PRESET" >&2; exit 1; }
PORT="${PORT:-8081}"

export PATH="$HOME/.local/bin:$PATH"
export DATA_DIR="$HOME/.open-webui"
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(cat "$DATA_DIR/.secret" 2>/dev/null || (mkdir -p "$DATA_DIR" && openssl rand -hex 32 | tee "$DATA_DIR/.secret"))}"
export ENABLE_OLLAMA_API=false
export OPENAI_API_KEYS="none"
export OPENAI_API_BASE_URLS="http://127.0.0.1:$PORT/v1"

open-webui serve --port 3000 &
PIDS+=("$!")

# --models-max cannot go inside the ini: the router reads it before presets load.
# Three, because [qwen3.8-27b], [llm] and [reranker] all stay resident.
MAX=3
echo "gpu-0-1: $(basename "$(readlink -f "$PRESET")") (--models-max $MAX, port $PORT)"

# NOTE: deliberately no --device. The router merges its own CLI args over every
# preset section, overwriting them, so a --device here would drag all three
# children onto one card. Each section in the preset sets its own `device`.
#
# SERVER_FLAGS carries a --models-max of its own; ours follows it and wins.
# shellcheck disable=SC2086
"$REPO/llama.cpp/llama-server" \
    $SERVER_FLAGS \
    --models-max "$MAX" \
    --models-preset "$PRESET" \
    --port "$PORT" &
PIDS+=("$!")

wait -n
