#!/usr/bin/env bash
# Install/update the one systemd user unit and retire the former split units.
set -euo pipefail

GPU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$GPU_DIR")"
UNIT="cicero-home-ai.service"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

mkdir -p "$UNIT_DIR"

for legacy in cicero-vulkan0.service cicero-vulkan1.service; do
    systemctl --user disable --now "$legacy" 2>/dev/null || true
    rm -f "$UNIT_DIR/$legacy"
done

sed "s|/home/gaperton/cicero-home-ai|$REPO|g" "$GPU_DIR/$UNIT" > "$UNIT_DIR/$UNIT"
systemctl --user daemon-reload
systemctl --user enable "$UNIT"
