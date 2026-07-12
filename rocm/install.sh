#!/usr/bin/env bash
# rocm/install.sh — Clone the ROCm llama.cpp checkout. Assumes the ROCm/HIP SDK is
# already installed (see rocm/.env — hipconfig must be on PATH).
# Self-contained: works standalone, or called directly (as root) from the top-level install.sh.
#   ./rocm/install.sh
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -eq 0 ]]; then
    sudo -u "$SUDO_USER" git clone https://github.com/ggml-org/llama.cpp "$BACKEND_DIR/llama.cpp"
else
    git clone https://github.com/ggml-org/llama.cpp "$BACKEND_DIR/llama.cpp"
fi
