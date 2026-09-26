#!/usr/bin/env bash
# vllm/install-service.sh — Install/update the systemd user unit from the repo copy.
set -euo pipefail

VLLM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$VLLM_DIR")"
UNIT="cicero-vllm.service"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

mkdir -p "$UNIT_DIR" "$REPO/logs"
sed "s|/home/gaperton/cicero-home-ai|$REPO|g" "$VLLM_DIR/$UNIT" > "$UNIT_DIR/$UNIT"
systemctl --user daemon-reload
