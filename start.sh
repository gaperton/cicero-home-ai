#!/usr/bin/env bash
# start.sh — Start the combined AI service.
set -euo pipefail

systemctl --user start cicero-home-ai.service
echo "Started. Status: ./switch"
