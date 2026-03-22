#!/usr/bin/env bash
# install.sh — First-time setup. Run with sudo.
#   sudo ./install.sh
set -euo pipefail

# Install system dependencies (Vulkan, build tools, tmux, mc)
apt-get update
apt-get install -y pciutils build-essential cmake curl libcurl4-openssl-dev libvulkan-dev glslc pipx tmux mc

# Install HuggingFace CLI for model downloads (as the actual user, not root)
sudo -u "$SUDO_USER" pipx install huggingface_hub[cli]
sudo -u "$SUDO_USER" pipx ensurepath

# Clone llama.cpp and fix ownership (cloned as root, owned by user)
git clone https://github.com/ggml-org/llama.cpp
chown -R "$SUDO_USER:$SUDO_USER" llama.cpp

# Build llama.cpp with Vulkan backend
cmake llama.cpp -B llama.cpp/build \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_VULKAN=ON

cmake --build llama.cpp/build --config Release -j --clean-first \
    --target llama-cli llama-mtmd-cli llama-server llama-gguf-split llama-bench

cp llama.cpp/build/bin/llama-* llama.cpp
