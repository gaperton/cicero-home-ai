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

# Instance 0 normally serves the benchmark's answer+judge models from
# presets/models-0.ini. Override for a judge sweep, which needs every judge on
# its own slots rather than only the answer model:
#   MODELS_0_PRESET=./presets/models-0-judge.ini ./run.sh
MODELS_0_PRESET="${MODELS_0_PRESET:-$SCRIPT_DIR/presets/models-0.ini}"
[ -e "$MODELS_0_PRESET" ] || { echo "run.sh: missing preset $MODELS_0_PRESET" >&2; exit 1; }
echo "run.sh: Vulkan0 preset -> $(readlink -f "$MODELS_0_PRESET")"

# shellcheck disable=SC2086
"$SCRIPT_DIR/llama.cpp/llama-server" \
    $SERVER_FLAGS \
    --models-preset "$MODELS_0_PRESET" \
    --device Vulkan0 \
    --port 8080 &
PIDS+=("$!")

# The Hindsight router has two profiles, one per LLM. presets/models-1.ini is a
# symlink to the active one; switch-hindsight-model.sh repoints it and the
# matching Hindsight env file together, since the two must agree or the router
# thrashes.
#   presets/models-1-oss.ini    gpt-oss-20b   — production, all four operations
#   presets/models-1-gemma.ini  gemma4-26b-a4b-qat — ingestion only, Reflect hangs
# Override for a one-off run with MODELS_1_PRESET=... ./run.sh
MODELS_1_PRESET="${MODELS_1_PRESET:-$SCRIPT_DIR/presets/models-1.ini}"
[ -e "$MODELS_1_PRESET" ] || { echo "run.sh: missing preset $MODELS_1_PRESET" >&2; exit 1; }
echo "run.sh: Vulkan1 preset -> $(readlink -f "$MODELS_1_PRESET")"

# shellcheck disable=SC2086
# --models-max 2 overrides SERVER_FLAGS' --models-max 1: this router keeps the
# active LLM and the qwen3-reranker-0.6b reranking model resident at once for
# Hindsight, instead of evicting one to load the other on every call.
"$SCRIPT_DIR/llama.cpp/llama-server" \
    $SERVER_FLAGS \
    --models-max 2 \
    --models-preset "$MODELS_1_PRESET" \
    --device Vulkan1 \
    --port 8081 &
PIDS+=("$!")

wait -n
