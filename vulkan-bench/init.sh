#!/usr/bin/env bash
# init.sh — First-time setup: clone a separate llama.cpp checkout and build it
# with the Vulkan backend, for comparison against the main ROCm build.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_DIR="$SCRIPT_DIR/llama.cpp"
TARGETS="llama-cli llama-server llama-bench"

CMAKE_FLAGS="-DGGML_VULKAN=ON -DGGML_NATIVE=1 -DCMAKE_BUILD_TYPE=Release"
export CMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG"
export CMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG"

if ! command -v glslc >/dev/null 2>&1; then
    echo "glslc not found — installing Vulkan SDK build deps (requires sudo)." >&2
    sudo apt-get update
    sudo apt-get install -y libvulkan-dev glslang-tools vulkan-tools mesa-vulkan-drivers
fi

if [[ -d "$LLAMA_DIR/.git" ]]; then
    echo "llama.cpp checkout already exists at $LLAMA_DIR; skipping clone."
else
    git clone https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
fi

cmake "$LLAMA_DIR" -B "$LLAMA_DIR/build" -DBUILD_SHARED_LIBS=OFF $CMAKE_FLAGS
cmake --build "$LLAMA_DIR/build" --config Release -j --target $TARGETS
cp "$LLAMA_DIR"/build/bin/llama-* "$LLAMA_DIR/"

echo "Done. Vulkan devices visible to this build:"
"$LLAMA_DIR/llama-cli" --list-devices 2>&1 | grep -A99 'Available devices' || true
