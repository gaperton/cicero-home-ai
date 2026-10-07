#!/usr/bin/env bash
# rad/run.sh — Open WebUI and the radiance server. Run by cicero-rad.service in
# the foreground; exits when either child dies.
#
# radiance: :$PORT, model $SERVED_MODEL_NAME. Open WebUI: :3000, pointed at it.
set -euo pipefail

RAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$RAD_DIR")"
cd "$REPO"

# The systemd user manager keeps the groups it started with. If the user was
# added to `docker` since, take the group for this process tree via sg.
if ! id -Gn | tr ' ' '\n' | grep -qx docker && id -Gn "$(id -un)" | tr ' ' '\n' | grep -qx docker \
        && [ -z "${RAD_RUN_SG:-}" ]; then
    exec env RAD_RUN_SG=1 sg docker -c "exec '$0'"
fi

set -a
# shellcheck source=config.env
source "$RAD_DIR/config.env"
RADIANCE_MODELS="$REPO/$RADIANCE_MODELS"
RADIANCE_STATE="$REPO/$RADIANCE_STATE"
set +a

[ -f "$RADIANCE_MODELS/$RADIANCE_MODEL" ] || { echo "rad/run.sh: no model at $RADIANCE_MODELS/$RADIANCE_MODEL" >&2; exit 1; }
# The engine does not create the disk tier's directory; without it the tier is off.
mkdir -p "$RADIANCE_STATE/kvcache/flashnext"

# A user unit cannot order itself after the system docker.service; wait for it.
for _ in $(seq 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
docker info >/dev/null 2>&1 || { echo "rad/run.sh: Docker is not reachable" >&2; exit 1; }

COMPOSE=(docker compose -f "$RAD_DIR/compose.yaml")
# A container left over from an unclean stop would hold the port and both cards.
"${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true

PIDS=()
cleanup() {
    kill "${PIDS[@]}" 2>/dev/null || true
    "${COMPOSE[@]}" down --timeout 60 >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 143' TERM INT

export PATH="$HOME/.local/bin:$PATH"
export DATA_DIR="$HOME/.open-webui"
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(cat "$DATA_DIR/.secret" 2>/dev/null || (mkdir -p "$DATA_DIR" && openssl rand -hex 32 | tee "$DATA_DIR/.secret"))}"
export ENABLE_OLLAMA_API=false
export OPENAI_API_KEYS="none"
export OPENAI_API_BASE_URLS="http://127.0.0.1:$PORT/v1"

open-webui serve --port 3000 &
PIDS+=("$!")

echo "rad: $RADIANCE_IMAGE, $RADIANCE_MODEL as $SERVED_MODEL_NAME on $HOST:$PORT (host pool $HOST_POOL_MIB MiB/card)"
"${COMPOSE[@]}" up --no-log-prefix &
PIDS+=("$!")

wait -n
