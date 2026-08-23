#!/usr/bin/env bash
# Install the version-matched Hindsight Control Plane and its systemd user unit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/hindsight-control-plane"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hindsight"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
ENV_FILE="$CONFIG_DIR/control-plane.env"
UNIT="hindsight-ui.service"
HINDSIGHT_PYTHON="${HINDSIGHT_PYTHON:-$HOME/.local/share/hindsight/venv/bin/python}"

api_version=""
if [[ -x "$HINDSIGHT_PYTHON" ]]; then
    api_version="$("$HINDSIGHT_PYTHON" -c \
        'from importlib.metadata import version; print(version("hindsight-api"))' \
        2>/dev/null || true)"
fi
CONTROL_PLANE_VERSION="${CONTROL_PLANE_VERSION:-${api_version:-0.9.1}}"

mkdir -p "$DATA_DIR" "$CONFIG_DIR" "$UNIT_DIR"

installed_version="$(node -e 'console.log(require(process.argv[1]).version)' \
    "$DATA_DIR/node_modules/@vectorize-io/hindsight-control-plane/package.json" \
    2>/dev/null || true)"

if [[ "$installed_version" != "$CONTROL_PLANE_VERSION" ]]; then
    if [[ ! -f "$DATA_DIR/package.json" ]]; then
        printf '%s\n' '{"name":"hindsight-control-plane-local","private":true}' > "$DATA_DIR/package.json"
    fi
    npm install --prefix "$DATA_DIR" --save-exact --no-audit --no-fund \
        "@vectorize-io/hindsight-control-plane@$CONTROL_PLANE_VERSION"
fi

touch "$ENV_FILE"
chmod 600 "$ENV_FILE"
if ! grep -q '^HINDSIGHT_CP_ACCESS_KEY=' "$ENV_FILE"; then
    printf 'HINDSIGHT_CP_ACCESS_KEY=%s\n' "$(openssl rand -hex 24)" >> "$ENV_FILE"
fi

sed "s|/home/gaperton|$HOME|g" "$SCRIPT_DIR/$UNIT" > "$UNIT_DIR/$UNIT"
systemctl --user daemon-reload
systemctl --user enable "$UNIT"
systemctl --user restart "$UNIT"

echo "Hindsight Control Plane: http://cicero.local:9999"
echo "Access key: $ENV_FILE"
