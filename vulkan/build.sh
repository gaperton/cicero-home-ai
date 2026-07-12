#!/usr/bin/env bash
# vulkan/build.sh — Pull latest llama.cpp and rebuild the Vulkan backend.
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BACKEND_DIR/.env"

TARGETS="llama-cli llama-mtmd-cli llama-server llama-gguf-split llama-bench"
LLAMA_DIR="$BACKEND_DIR/llama.cpp"

git -C "$LLAMA_DIR" pull
cmake "$LLAMA_DIR" -B "$LLAMA_DIR/build" -DBUILD_SHARED_LIBS=OFF $CMAKE_FLAGS
cmake --build "$LLAMA_DIR/build" --config Release -j --target $TARGETS
cp "$LLAMA_DIR"/build/bin/llama-* "$LLAMA_DIR/"
