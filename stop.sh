#!/usr/bin/env bash
# stop.sh — Stop the combined AI service.
set -euo pipefail

systemctl --user stop cicero-home-ai.service
echo "Stopped."
