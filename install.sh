#!/usr/bin/env bash
# install.sh — First-time setup. Run with sudo.
#   sudo ./install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]] || {
    echo "install.sh: run as your user with sudo: sudo ./install.sh" >&2; exit 1; }

# radiance runs in Docker with its own ROCm userspace; the host needs only the
# amdgpu kernel driver, plus amd-smi for the power cap.
apt-get update
apt-get install -y ripgrep pipx tmux mc curl openssl
# Skipped when Docker with Compose v2 is already there, e.g. docker-ce from Docker's repo.
docker compose version >/dev/null 2>&1 || apt-get install -y docker.io docker-compose-v2

if ! command -v amd-smi >/dev/null; then
    echo "install.sh: amd-smi not found (ships with ROCm, https://repo.radeon.com); needed for the GPU power cap." >&2
    exit 1
fi

# Cap both GPUs' power at boot.
"$SCRIPT_DIR/gpu-power/install.sh"

# rad/run.sh starts the container as the user; it takes the group via sg until the next login.
usermod -aG docker "$SUDO_USER"

SUDO_UID=$(id -u "$SUDO_USER")
SUDO_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

# User-level tools: the hf CLI for the model download, and Open WebUI, which
# supports Python 3.11/3.12 while the host's default Python may be newer.
sudo -u "$SUDO_USER" pipx install 'huggingface_hub[cli]'
sudo -u "$SUDO_USER" pipx install uv
UV_BIN="$SUDO_HOME/.local/bin/uv"
sudo -u "$SUDO_USER" "$UV_BIN" python install 3.11
OPEN_WEBUI_PYTHON=$(sudo -u "$SUDO_USER" "$UV_BIN" python find 3.11)
sudo -u "$SUDO_USER" pipx install --python "$OPEN_WEBUI_PYTHON" open-webui
sudo -u "$SUDO_USER" pipx ensurepath

# Install and enable the systemd user service.
run_user() { sudo -u "$SUDO_USER" HOME="$SUDO_HOME" XDG_RUNTIME_DIR="/run/user/$SUDO_UID" "$@"; }
loginctl enable-linger "$SUDO_USER"
run_user "$SCRIPT_DIR/rad/install-service.sh"
echo "Systemd user service installed and enabled. Run ./update.sh to pull the image, download the model and start."
