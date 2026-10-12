#!/usr/bin/env bash
# rad/install-service.sh — Install/update and enable the user unit; retire the
# units of the removed llama.cpp, vLLM and audio stacks.
set -euo pipefail

RAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$RAD_DIR")"
UNIT="cicero-rad.service"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

mkdir -p "$UNIT_DIR" "$REPO/logs"

for legacy in cicero-home-ai.service cicero-vllm.service cicero-tts-server.service \
        cicero-asr-proxy.service cicero-vulkan0.service cicero-vulkan1.service; do
    systemctl --user disable --now "$legacy" 2>/dev/null || true
    rm -f "$UNIT_DIR/$legacy"
done

sed "s|/home/gaperton/cicero-home-ai|$REPO|g" "$RAD_DIR/$UNIT" > "$UNIT_DIR/$UNIT"
systemctl --user daemon-reload
systemctl --user enable "$UNIT"
