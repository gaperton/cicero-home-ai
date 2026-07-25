#!/usr/bin/env bash
# vulkan/run.sh — Launch llama-server on Vulkan, one instance per GPU (ports 8080/8081).
#   Called by the top-level run.sh; can also be run standalone for backend-only testing.
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$BACKEND_DIR")"
cd "$REPO_DIR"

[[ -f "$REPO_DIR/.env" ]] && source "$REPO_DIR/.env"
source "$BACKEND_DIR/.env"

# RADV_DEBUG=nocompute suppresses a spurious AMD Vulkan warning
export RADV_DEBUG=nocompute

# GPU 0 — port 8080 (background)
# shellcheck disable=SC2086
GGML_VK_VISIBLE_DEVICES=0 "$BACKEND_DIR/llama.cpp/llama-server" \
    $SERVER_FLAGS_COMMON \
    $SERVER_FLAGS_EXTRA \
    --models-preset "$BACKEND_DIR/models-0.ini" \
    --port 8080 &
SERVER0_PID=$!
trap 'kill $SERVER0_PID 2>/dev/null' EXIT

# GPU 1 — port 8081 (foreground)
# shellcheck disable=SC2086
GGML_VK_VISIBLE_DEVICES=1 "$BACKEND_DIR/llama.cpp/llama-server" \
    $SERVER_FLAGS_COMMON \
    $SERVER_FLAGS_EXTRA \
    --models-preset "$BACKEND_DIR/models-1.ini" \
    --port 8081
