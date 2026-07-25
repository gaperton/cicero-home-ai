#!/usr/bin/env bash
# install.sh — First-time setup. Run with sudo.
#   sudo ./install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install system dependencies shared by both backends (tmux, mc, node, etc.)
apt-get update
apt-get install -y ripgrep ffmpeg pciutils pipx tmux mc nodejs npm

# Each backend's own install.sh needs root for apt-get, so call them directly (they
# drop to $SUDO_USER themselves for the git clone). Model setup is pure user-level.
"$SCRIPT_DIR/vulkan/install.sh"
"$SCRIPT_DIR/rocm/install.sh"
sudo -u "$SUDO_USER" "$SCRIPT_DIR/models/install.sh"

SUDO_UID=$(id -u "$SUDO_USER")
SUDO_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

# Install user-level tools. Open WebUI supports Python 3.11/3.12, while the host's
# default Python may be newer, so provision and select a compatible interpreter.
sudo -u "$SUDO_USER" pipx install uv
UV_BIN="$SUDO_HOME/.local/bin/uv"
sudo -u "$SUDO_USER" "$UV_BIN" python install 3.11
OPEN_WEBUI_PYTHON=$(sudo -u "$SUDO_USER" "$UV_BIN" python find 3.11)
sudo -u "$SUDO_USER" pipx install --python "$OPEN_WEBUI_PYTHON" open-webui
sudo -u "$SUDO_USER" pipx ensurepath

# Create logs directory
sudo -u "$SUDO_USER" mkdir -p "$SCRIPT_DIR/logs"

# Install and enable the systemd user service
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