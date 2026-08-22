#!/usr/bin/env bash
# gpu-0-1/run.sh — one llama-server router across BOTH cards, port 8081.
# Run by cicero-vulkan1.service. Foreground; exits if the server dies.
#
# This is the combined topology: a single router owns ROCm0 and ROCm1, and all
# three models stay resident. It replaces the old pair of one-router-per-card
# instances, so gpu-0/run.sh and gpu-1/run.sh are dormant while this is in use
# (their presets are still there — see README to revert).
#
# Port 8081, not 8080, on purpose: the section names [llm] and [reranker] are
# the ids Hindsight resolves, so keeping its port too means no HINDSIGHT_API_*
# env change. Open WebUI is a separate unit now, gpu-0-1/webui.sh, pointed here.
set -euo pipefail

GPU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$GPU_DIR")"
cd "$REPO"          # preset `model =` paths are relative to the repo root
source .env

PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT

PRESET="${PRESET:-$GPU_DIR/active.ini}"
[ -e "$PRESET" ] || { echo "gpu-0-1/run.sh: missing preset $PRESET" >&2; exit 1; }

# --models-max cannot go inside the ini: the router reads it before presets load.
# Three, because [qwen3.8-27b], [llm] and [reranker] all stay resident.
MAX=3
PORT="${PORT:-8081}"
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
