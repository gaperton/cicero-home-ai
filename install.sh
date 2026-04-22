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

# Clone two llama.cpp checkouts (one per backend) and fix ownership
git clone https://github.com/ggml-org/llama.cpp llama-vulkan
git clone https://github.com/ggml-org/llama.cpp llama-rocm
chown -R "$SUDO_USER:$SUDO_USER" llama-vulkan llama-rocm

# Create logs directory
sudo -u "$SUDO_USER" mkdir -p "$SCRIPT_DIR/logs"

# Install and enable the systemd user service
SUDO_UID=$(id -u "$SUDO_USER")
SUDO_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
USER_SYSTEMD_DIR="$SUDO_HOME/.config/systemd/user"
sudo -u "$SUDO_USER" mkdir -p "$USER_SYSTEMD_DIR"
sed "s|/home/gaperton/data/cicero-home-ai|$SCRIPT_DIR|g" \
    "$SCRIPT_DIR/systemd/cicero-home-ai.service" \
    > "$USER_SYSTEMD_DIR/cicero-home-ai.service"
chown "$SUDO_USER:$SUDO_USER" "$USER_SYSTEMD_DIR/cicero-home-ai.service"
loginctl enable-linger "$SUDO_USER"
sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$SUDO_UID" systemctl --user daemon-reload
sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$SUDO_UID" systemctl --user enable cicero-home-ai.service
echo "Systemd user service installed and enabled. Run ./update.sh to build and start."