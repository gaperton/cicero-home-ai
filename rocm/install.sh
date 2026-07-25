#!/usr/bin/env bash
# rocm/install.sh — Clone the ROCm llama.cpp checkout. Assumes the ROCm/HIP SDK is
# already installed (see rocm/.env — hipconfig must be on PATH).
# Self-contained: works standalone, or called directly (as root) from the top-level install.sh.
#   ./rocm/install.sh
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_DIR="$BACKEND_DIR/llama.cpp"

if [[ $EUID -eq 0 ]]; then
    apt-get update
    apt-get install -y build-essential cmake ccache curl libcurl4-openssl-dev
else
    sudo apt-get update
    sudo apt-get install -y build-essential cmake ccache curl libcurl4-openssl-dev
fi

if [[ -d "$LLAMA_DIR/.git" ]]; then
    echo "llama.cpp checkout already exists at $LLAMA_DIR; skipping clone."
elif [[ $EUID -eq 0 ]]; then
    sudo -u "$SUDO_USER" git clone https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
else
    git clone https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
fi
