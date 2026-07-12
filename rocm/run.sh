#!/usr/bin/env bash
# rocm/run.sh — Launch llama-server on ROCm, split-mode=layer across both GPUs (port 8080).
#   Called by the top-level run.sh; can also be run standalone for backend-only testing.
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$BACKEND_DIR")"
cd "$REPO_DIR"

[[ -f "$REPO_DIR/.env" ]] && source "$REPO_DIR/.env"
source "$BACKEND_DIR/.env"

WEBUI_CONFIG_ARGS=()
[[ -f "$REPO_DIR/webui-config.json" ]] && WEBUI_CONFIG_ARGS=(--webui-config-file "$REPO_DIR/webui-config.json")

# shellcheck disable=SC2086
HIP_VISIBLE_DEVICES=0,1 "$BACKEND_DIR/llama.cpp/llama-server" \
    $SERVER_FLAGS_COMMON \
    $SERVER_FLAGS_EXTRA \
    --models-preset "$BACKEND_DIR/models.ini" \
    --port 8080 \
    "${WEBUI_CONFIG_ARGS[@]}"
