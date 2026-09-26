#!/usr/bin/env bash
# vllm/install.sh — Pull the image, download the model, install the user unit.
#
#   ./vllm/install.sh            # prepare; the llama.cpp stack stays the boot default
#   ./vllm/install.sh --enable   # also make cicero-vllm.service the boot default
#
# Safe to re-run: the image pull and model download skip what is already there.
# Needs Docker (user in the `docker` group) and the `hf` CLI from models/install.sh.
set -euo pipefail

VLLM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT="cicero-vllm.service"
export PATH="$HOME/.local/bin:$PATH"

ENABLE=0
case "${1:-}" in
    "") ;;
    --enable) ENABLE=1 ;;
    *) echo "usage: $0 [--enable]" >&2; exit 1 ;;
esac

# shellcheck source=config.env
source "$VLLM_DIR/config.env"

command -v hf >/dev/null || { echo "error: 'hf' not found; run ./models/install.sh first" >&2; exit 1; }
docker info >/dev/null 2>&1 || {
    echo "error: cannot reach Docker. Log in again after 'usermod -aG docker', or run: sg docker -c $0" >&2
    exit 1
}

# --- Image (~4 GB compressed).
docker pull "$IMAGE"

# --- Model (~29 GB). hf skips files that are already complete.
"$VLLM_DIR/download-model.sh"

mkdir -p "$VLLM_DIR/cache"

# --- Unit. Conflicts= makes it mutually exclusive with the llama.cpp stack.
"$VLLM_DIR/install-service.sh"

if [ "$ENABLE" = 1 ]; then
    systemctl --user disable cicero-home-ai.service cicero-tts-server.service 2>/dev/null || true
    systemctl --user enable "$UNIT"
    echo "Enabled $UNIT as the boot default (llama.cpp stack and TTS disabled)."
fi
echo "Installed. Start with ./vllm/start.sh (stops the llama.cpp stack and TTS)."
