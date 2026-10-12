#!/usr/bin/env bash
# update.sh — Pull the pinned radiance image, download the model if missing,
# sync the user unit, and (re)start the stack.
#
#   ./update.sh            # re-pull RADIANCE_IMAGE from rad/config.env
#   ./update.sh 1.2.4      # switch rad/config.env to that radiance tag first
#
# Needs Docker (user in the `docker` group) and the `hf` CLI from install.sh.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT="cicero-rad.service"
export PATH="$HOME/.local/bin:$PATH"

TAG="${1:-}"
[ -z "$TAG" ] || [[ "$TAG" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "error: not a version tag: $TAG" >&2; exit 1; }

# See rad/run.sh: take the docker group if the login session predates it.
if ! id -Gn | tr ' ' '\n' | grep -qx docker && id -Gn "$(id -un)" | tr ' ' '\n' | grep -qx docker \
        && [ -z "${UPDATE_SG:-}" ]; then
    exec env UPDATE_SG=1 sg docker -c "exec '$0' $TAG"
fi

# shellcheck source=rad/config.env
source "$REPO/rad/config.env"

# A new tag is written to config.env only once its image has been pulled.
if [ -n "$TAG" ]; then
    RADIANCE_IMAGE="${RADIANCE_IMAGE%:*}:$TAG"
    docker pull "$RADIANCE_IMAGE"
    sed -i "s|^RADIANCE_IMAGE=.*|RADIANCE_IMAGE=$RADIANCE_IMAGE|" "$REPO/rad/config.env"
else
    docker pull "$RADIANCE_IMAGE"
fi

# The model is ~114 GiB and named by version, so an existing file is never re-fetched.
model="$REPO/$RADIANCE_MODELS/$RADIANCE_MODEL"
if [ ! -f "$model" ]; then
    command -v hf >/dev/null || { echo "error: 'hf' not found; run sudo ./install.sh first" >&2; exit 1; }
    hf download "$RADIANCE_MODEL_REPO" "$RADIANCE_MODEL" --local-dir "$REPO/$RADIANCE_MODELS"
fi

"$REPO/rad/install-service.sh"
systemctl --user restart "$UNIT"
echo "Updated: $RADIANCE_IMAGE, $RADIANCE_MODEL. Log: tail -f logs/rad.log"
