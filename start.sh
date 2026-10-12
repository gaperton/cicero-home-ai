#!/usr/bin/env bash
# start.sh — Start the radiance stack.
set -euo pipefail

systemctl --user start cicero-rad.service
echo "Started. Log: tail -f logs/rad.log"
