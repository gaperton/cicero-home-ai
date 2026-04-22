#!/usr/bin/env bash
# update.sh — Pull latest llama.cpp, rebuild both backends, and refresh models from HuggingFace.
#   ./update.sh           # rebuild both
#   ./update.sh vulkan    # rebuild vulkan only
#   ./update.sh rocm      # rebuild rocm only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="$HOME/.local/bin:$PATH"
source .env

TARGETS="llama-cli llama-mtmd-cli llama-server llama-gguf-split llama-bench"
BACKEND="${1:-both}"

"$SCRIPT_DIR/stop.sh" || true

build() {
    local dir="$1" flags="$2"
    git -C "$dir" pull
    cmake "$dir" -B "$dir/build" -DBUILD_SHARED_LIBS=OFF $flags
    cmake --build "$dir/build" --config Release -j --target $TARGETS
    cp "$dir"/build/bin/llama-* "$dir/"
}

[[ "$BACKEND" == "vulkan" || "$BACKEND" == "both" ]] && build llama-vulkan "$CMAKE_VULKAN_FLAGS"
[[ "$BACKEND" == "rocm"   || "$BACKEND" == "both" ]] && build llama-rocm   "$CMAKE_ROCM_FLAGS"

# Download/update models from HuggingFace (skips unchanged files)
hf download unsloth/Qwen3.6-27B-GGUF \
    Qwen3.6-27B-UD-Q5_K_XL.gguf --local-dir models/

hf download unsloth/Qwen3.6-35B-A3B-GGUF \
    Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf --local-dir models/

hf download unsloth/gemma-4-31B-it-GGUF \
    gemma-4-31B-it-UD-Q5_K_XL.gguf --local-dir models/

"$SCRIPT_DIR/start.sh" || true
