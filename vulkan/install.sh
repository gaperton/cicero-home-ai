#!/usr/bin/env bash
# vulkan/install.sh — Install Vulkan build deps and clone the Vulkan llama.cpp checkout.
# Self-contained: works standalone, or called directly (as root) from the top-level install.sh.
#   ./vulkan/install.sh
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -eq 0 ]]; then
    apt-get update
    apt-get install -y spirv-headers libvulkan-dev glslc
    sudo -u "$SUDO_USER" git clone https://github.com/ggml-org/llama.cpp "$BACKEND_DIR/llama.cpp"
else
    sudo apt-get update
    sudo apt-get install -y spirv-headers libvulkan-dev glslc
    git clone https://github.com/ggml-org/llama.cpp "$BACKEND_DIR/llama.cpp"
fi
