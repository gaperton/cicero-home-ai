#!/usr/bin/env bash
# build.sh — Pull latest llama.cpp and rebuild the Vulkan backend.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_DIR="$SCRIPT_DIR/llama.cpp"
TARGETS="llama-cli llama-server llama-bench"

CMAKE_FLAGS="-DGGML_VULKAN=ON -DGGML_NATIVE=1 -DCMAKE_BUILD_TYPE=Release"
export CMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG"
export CMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG"

git -C "$LLAMA_DIR" pull
cmake "$LLAMA_DIR" -B "$LLAMA_DIR/build" -DBUILD_SHARED_LIBS=OFF $CMAKE_FLAGS
cmake --build "$LLAMA_DIR/build" --config Release -j --target $TARGETS
cp "$LLAMA_DIR"/build/bin/llama-* "$LLAMA_DIR/"
