#!/usr/bin/env bash
# stop.sh — Stop the radiance stack.
set -euo pipefail

systemctl --user stop cicero-rad.service
echo "Stopped."
