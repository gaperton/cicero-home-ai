#!/usr/bin/env bash
# Upgrade the bare-metal Hindsight API and its version-matched Control Plane.
#
# Usage:
#   ./hindsight/update.sh          # latest stable version from PyPI
#   ./hindsight/update.sh 0.9.1    # explicit version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HINDSIGHT_HOME="${HINDSIGHT_HOME:-$HOME/.local/share/hindsight}"
HINDSIGHT_PYTHON="$HINDSIGHT_HOME/venv/bin/python"
UV_BIN="${UV_BIN:-$HOME/.local/bin/uv}"
BACKUP_DIR="${HINDSIGHT_BACKUP_DIR:-$HOME/backups/hindsight}"
API_URL="${HINDSIGHT_HEALTH_URL:-http://127.0.0.1:8888/health}"
UI_URL="${HINDSIGHT_UI_URL:-http://127.0.0.1:9999/}"

usage() {
    echo "usage: $(basename "$0") [VERSION]"
    echo "  no VERSION: install the latest stable hindsight-api release"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi
[[ $# -le 1 ]] || { usage >&2; exit 2; }

for command in curl pg_dump systemctl node npm openssl; do
    command -v "$command" >/dev/null || { echo "error: missing command: $command" >&2; exit 1; }
done
[[ -x "$UV_BIN" ]] || { echo "error: uv not found: $UV_BIN" >&2; exit 1; }
[[ -x "$HINDSIGHT_PYTHON" ]] || { echo "error: Hindsight venv not found: $HINDSIGHT_PYTHON" >&2; exit 1; }

current_version="$("$HINDSIGHT_PYTHON" -c \
    'from importlib.metadata import version; print(version("hindsight-api"))')"

if [[ $# -eq 1 ]]; then
    target_version="$1"
else
    target_version="$(curl -fsSL https://pypi.org/pypi/hindsight-api/json | \
        "$HINDSIGHT_PYTHON" -c 'import json,sys; print(json.load(sys.stdin)["info"]["version"])')"
fi

[[ "$target_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([a-zA-Z0-9.-]+)?$ ]] || {
    echo "error: invalid version: $target_version" >&2
    exit 1
}

echo "Hindsight API: $current_version -> $target_version"
echo "Checking for matching Control Plane $target_version ..."
npm view "@vectorize-io/hindsight-control-plane@$target_version" version >/dev/null

if [[ "$current_version" != "$target_version" ]]; then
    mkdir -p "$BACKUP_DIR"
    backup_file="$BACKUP_DIR/hindsight-before-${current_version}-to-${target_version}-$(date +%Y%m%d-%H%M%S).dump"
    echo "Backing up PostgreSQL -> $backup_file"
    pg_dump --dbname=hindsight --format=custom --file="$backup_file"

    echo "Stopping Hindsight services ..."
    systemctl --user stop hindsight-ui.service hindsight.service

    echo "Upgrading hindsight-api ..."
    if ! "$UV_BIN" pip install \
        --python "$HINDSIGHT_PYTHON" \
        --upgrade "hindsight-api==$target_version"; then
        echo "API package upgrade failed; attempting to restart the previous installation." >&2
        systemctl --user start hindsight.service || true
        systemctl --user start hindsight-ui.service || true
        exit 1
    fi

    installed_version="$("$HINDSIGHT_PYTHON" -c \
        'from importlib.metadata import version; print(version("hindsight-api"))')"
    [[ "$installed_version" == "$target_version" ]] || {
        echo "error: installed API version is $installed_version, expected $target_version" >&2
        exit 1
    }

else
    echo "API is already at the requested version; skipping database backup and Python reinstall."
fi

echo "Starting Hindsight API (startup applies database migrations) ..."
systemctl --user start hindsight.service
api_ready=false
for _ in {1..60}; do
    if curl -fsS "$API_URL" >/dev/null 2>&1; then
        api_ready=true
        break
    fi
    sleep 2
done
if [[ "$api_ready" != true ]]; then
    echo "error: Hindsight API did not become healthy: $API_URL" >&2
    if [[ -n "${backup_file:-}" ]]; then
        echo "backup: $backup_file" >&2
    fi
    journalctl --user -u hindsight.service -n 50 --no-pager >&2 || true
    exit 1
fi

echo "Installing matching Control Plane $target_version ..."
CONTROL_PLANE_VERSION="$target_version" "$SCRIPT_DIR/ui/install.sh"

ui_ready=false
for _ in {1..30}; do
    if curl -fsS "$UI_URL" >/dev/null 2>&1; then
        ui_ready=true
        break
    fi
    sleep 2
done
[[ "$ui_ready" == true ]] || {
    echo "error: Hindsight Control Plane did not become reachable: $UI_URL" >&2
    journalctl --user -u hindsight-ui.service -n 50 --no-pager >&2 || true
    exit 1
}

control_plane_version="$(node -e \
    'console.log(require(process.argv[1]).version)' \
    "$HOME/.local/share/hindsight-control-plane/node_modules/@vectorize-io/hindsight-control-plane/package.json")"

echo "Upgrade complete:"
echo "  API:           $target_version ($API_URL)"
echo "  Control Plane: $control_plane_version ($UI_URL)"
if [[ -n "${backup_file:-}" ]]; then
    echo "  Backup:        $backup_file"
fi
