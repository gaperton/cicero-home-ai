#!/usr/bin/env bash
# update.sh — Pull latest llama.cpp, rebuild, refresh models, and upgrade Open WebUI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="$HOME/.local/bin:$PATH"

# Keep the installed unit in sync and migrate away from the former split units.
"$SCRIPT_DIR/gpu-0-1/install-service.sh"

"$SCRIPT_DIR/stop.sh" || true

"$SCRIPT_DIR/build.sh"

# Download/update models from HuggingFace (skips unchanged files)
"$SCRIPT_DIR/models/update.sh"

# Open WebUI is a pipx app launched by gpu-0-1/run.sh; keep it current with the
# rest of the stack. Backup the SQLite DB first so a bad migration is recoverable.
if command -v pipx >/dev/null 2>&1 && pipx list 2>/dev/null | grep -q 'package open-webui'; then
  BACKUP_DIR="${OPEN_WEBUI_BACKUP_DIR:-$HOME/.backups/open-webui}"
  DATA_DIR="${DATA_DIR:-$HOME/.open-webui}"
  mkdir -p "$BACKUP_DIR"
  stamp="$(date -u +%Y%m%d-%H%M%S)"
  for f in webui.db webui.db-shm webui.db-wal; do
    [ -e "$DATA_DIR/$f" ] && cp -a "$DATA_DIR/$f" "$BACKUP_DIR/${f}.${stamp}"
  done
  pipx upgrade open-webui --include-injected
fi

"$SCRIPT_DIR/start.sh" || true
