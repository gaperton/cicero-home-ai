#!/usr/bin/env bash
# Install the GPU power-cap system unit and apply the cap now. Run with sudo.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT="cicero-gpu-power.service"

[[ $EUID -eq 0 ]] || { echo "gpu-power/install.sh: run with sudo" >&2; exit 1; }

# A root-owned copy, so the unit never executes a file writable by the repo owner.
install -m 755 "$DIR/set-power-cap.sh" /usr/local/libexec/cicero-gpu-power.sh
install -m 644 "$DIR/$UNIT" "/etc/systemd/system/$UNIT"
systemctl daemon-reload
systemctl enable "$UNIT"
systemctl restart "$UNIT"
systemctl --no-pager --lines=5 status "$UNIT"
