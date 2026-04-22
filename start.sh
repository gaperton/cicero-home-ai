#!/usr/bin/env bash
# start.sh — Start the cicero-home-ai systemd user service.
set -euo pipefail

systemctl --user start cicero-home-ai.service
echo "Started. Status: systemctl --user status cicero-home-ai.service"
