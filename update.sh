#!/usr/bin/env bash
# update.sh — Pull latest llama.cpp, rebuild, and refresh models from HuggingFace.
#   ./update.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="$HOME/.local/bin:$PATH"
source .env

# Pull latest llama.cpp source
git -C llama.cpp pull

# Rebuild (incremental)
cmake llama.cpp -B llama.cpp/build \
    -DBUILD_SHARED_LIBS=OFF \
    "$CMAKE_GPU_FLAG"

cmake --build llama.cpp/build --config Release -j \
    --target llama-cli llama-mtmd-cli llama-server llama-gguf-split llama-bench

cp llama.cpp/build/bin/llama-* llama.cpp

# Download/update models from HuggingFace (skips unchanged files)
hf download unsloth/Qwen3.5-27B-GGUF \
    Qwen3.5-27B-UD-Q5_K_XL.gguf --local-dir models/

hf download unsloth/Qwen3.5-35B-A3B-GGUF \
    Qwen3.5-35B-A3B-UD-Q5_K_XL.gguf --local-dir models/

hf download unsloth/GLM-4.7-Flash-GGUF \
    GLM-4.7-Flash-UD-Q5_K_XL.gguf --local-dir models/
