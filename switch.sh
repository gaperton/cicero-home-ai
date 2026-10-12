#!/usr/bin/env bash
# switch.sh — Serve another model profile (rad/profiles/<name>.env): download its model if
# missing, make it active in rad/config.env, restart the stack.
#
#   ./switch.sh              # list profiles; * marks the active one
#   ./switch.sh 27b          # Qwen3.8-27B
#   ./switch.sh flashnext    # Qwen3.8-Flash-Next
#
# Both are served as SERVED_MODEL_NAME; the dated "rad:" lines in logs/rad.log say which ran when.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT="cicero-rad.service"

# shellcheck source=rad/config.env
source "$REPO/rad/config.env"

if [ $# -eq 0 ]; then
    for p in "$REPO"/rad/profiles/*.env; do
        n="$(basename "$p" .env)"
        if [ "$n" = "$RADIANCE_PROFILE" ]; then echo "* $n"; else echo "  $n"; fi
    done
    exit 0
fi

# The profile becomes active only once its model is on disk.
"$REPO/rad/fetch-model.sh" "$1"
sed -i "s|^RADIANCE_PROFILE=.*|RADIANCE_PROFILE=$1|" "$REPO/rad/config.env"
systemctl --user restart "$UNIT"
echo "Switched to $1. The model loads for a few minutes: tail -f logs/rad.log"
