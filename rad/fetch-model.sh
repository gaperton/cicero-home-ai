#!/usr/bin/env bash
# rad/fetch-model.sh <profile> — Download a profile's model at its pinned revision into
# RADIANCE_MODELS unless the file is already there. Used by update.sh and switch.sh.
set -euo pipefail

RAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$RAD_DIR")"
export PATH="$HOME/.local/bin:$PATH"

name="${1:?usage: rad/fetch-model.sh <profile>}"
profile="$RAD_DIR/profiles/$name.env"
[[ "$name" =~ ^[A-Za-z0-9._-]+$ && -f "$profile" ]] || {
    echo "error: no profile '$name'; have: $(cd "$RAD_DIR/profiles" && ls ./*.env | sed 's|^\./||; s|\.env$||' | tr '\n' ' ')" >&2
    exit 1
}

# shellcheck source=config.env
source "$RAD_DIR/config.env"
# shellcheck source=/dev/null
source "$profile"

# hf writes to a temporary file and renames it when done, so an existing file is complete.
model="$REPO/$RADIANCE_MODELS/$RADIANCE_MODEL"
[ -f "$model" ] && exit 0
command -v hf >/dev/null || { echo "error: 'hf' not found; run sudo ./install.sh first" >&2; exit 1; }
hf download "$RADIANCE_MODEL_REPO" "$RADIANCE_MODEL" --revision "$RADIANCE_MODEL_REVISION" \
    --local-dir "$REPO/$RADIANCE_MODELS"
