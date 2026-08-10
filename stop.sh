#!/usr/bin/env bash
# stop.sh — Stop both per-GPU llama-server services.
set -euo pipefail

systemctl --user stop cicero-vulkan0.service cicero-vulkan1.service
echo "Stopped."
