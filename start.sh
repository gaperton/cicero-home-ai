#!/usr/bin/env bash
# start.sh — Start both per-GPU llama-server services.
set -euo pipefail

systemctl --user start cicero-vulkan0.service cicero-vulkan1.service
echo "Started. Status: ./switch"
