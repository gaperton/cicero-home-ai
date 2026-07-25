#!/usr/bin/env bash
# vulkan/install.sh — Install Vulkan build deps and clone the Vulkan llama.cpp checkout.
# Self-contained: works standalone, or called directly (as root) from the top-level install.sh.
#   ./vulkan/install.sh
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_DIR="$BACKEND_DIR/llama.cpp"

if [[ $EUID -eq 0 ]]; then
    apt-get update
    apt-get install -y spirv-headers libvulkan-dev glslc
else
    sudo apt-get update
    sudo apt-get install -y spirv-headers libvulkan-dev glslc
fi

if [[ -d "$LLAMA_DIR/.git" ]]; then
    echo "llama.cpp checkout already exists at $LLAMA_DIR; skipping clone."
elif [[ $EUID -eq 0 ]]; then
    sudo -u "$SUDO_USER" git clone https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
else
    git clone https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
fi
