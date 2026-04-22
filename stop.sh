#!/usr/bin/env bash
# stop.sh — Stop the cicero-home-ai systemd user service.
set -euo pipefail

systemctl --user stop cicero-home-ai.service
echo "Stopped."
