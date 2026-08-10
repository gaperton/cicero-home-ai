#!/usr/bin/env bash
# gpu-1/run.sh — llama-server on Vulkan1:8081 (Hindsight's router).
# Run by cicero-vulkan1.service. Foreground; exits if the server dies.
set -euo pipefail

GPU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$GPU_DIR")"
cd "$REPO"          # preset `model =` paths are relative to the repo root
source .env

PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT

# active.ini is a symlink ./switch repoints.
PRESET="${PRESET:-$GPU_DIR/active.ini}"
[ -e "$PRESET" ] || { echo "gpu-1/run.sh: missing preset $PRESET" >&2; exit 1; }

# --models-max cannot go inside the ini: the router reads it before presets load.
# [llm] and [reranker] both carry load-on-startup and must stay resident
# together, or Hindsight evicts one on every call.
MAX=2
echo "gpu-1: $(basename "$(readlink -f "$PRESET")") (--models-max $MAX)"

# shellcheck disable=SC2086
"$REPO/llama.cpp/llama-server" \
    $SERVER_FLAGS \
    --models-max "$MAX" \
    --models-preset "$PRESET" \
    --device Vulkan1 \
    --port 8081 &
PIDS+=("$!")

wait -n
