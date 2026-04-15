#!/usr/bin/env bash
# install.sh — First-time setup. Run with sudo.
#   sudo ./install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

# Install system dependencies (Vulkan, build tools, tmux, mc)
apt-get update
apt-get install -y ripgrep spirv-headers ffmpeg pciutils build-essential cmake ccache curl libcurl4-openssl-dev libvulkan-dev glslc pipx tmux mc nodejs npm

# Install HuggingFace CLI, mcp-proxy and uv (as the actual user, not root)
sudo -u "$SUDO_USER" pipx install huggingface_hub[cli]
sudo -u "$SUDO_USER" pipx install mcp-proxy
sudo -u "$SUDO_USER" pipx install open-webui
sudo -u "$SUDO_USER" pipx install uv
sudo -u "$SUDO_USER" pipx ensurepath

# Clone llama.cpp and fix ownership (cloned as root, owned by user)
git clone https://github.com/ggml-org/llama.cpp
chown -R "$SUDO_USER:$SUDO_USER" llama.cpp