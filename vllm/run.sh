#!/usr/bin/env bash
# vllm/run.sh — Open WebUI plus the vLLM server across both cards.
# Run by cicero-vllm.service. Foreground; exits if either child dies.
#
# vLLM serves the OpenAI API on :$PORT (8080, where the llama.cpp router used to
# be) as model $SERVED_MODEL_NAME. Open WebUI listens on :3000 and points at it.
set -euo pipefail

VLLM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$VLLM_DIR")"
cd "$REPO"

# Groups are fixed when the systemd user manager starts. If the user joined
# `docker` after that (Docker was installed later), this process lacks it until a
# re-login or reboot; pick it up for this process tree instead.
if ! id -Gn | tr ' ' '\n' | grep -qx docker && id -Gn "$(id -un)" | tr ' ' '\n' | grep -qx docker \
        && [ -z "${VLLM_RUN_SG:-}" ]; then
    exec env VLLM_RUN_SG=1 sg docker -c "exec '$0'"
fi

set -a
# shellcheck source=config.env
source "$VLLM_DIR/config.env"
MODEL_PATH="$REPO/$MODEL_DIR"
CACHE_PATH="$VLLM_DIR/cache"
CALIB_PATH="$VLLM_DIR/calibration"
# The sidecar and its .manifest.json are mounted at /calibration.
RADIANCE_FP8_KV_SCALES=""
if [ -n "${FP8_KV_SCALES:-}" ]; then
    [ -f "$REPO/$FP8_KV_SCALES" ] || { echo "vllm/run.sh: missing FP8 KV scales $FP8_KV_SCALES" >&2; exit 1; }
    RADIANCE_FP8_KV_SCALES="/calibration/$(basename "$FP8_KV_SCALES")"
fi
set +a

case "$SPEC" in
    mtp)
        export RADIANCE_SPECULATIVE_CONFIG="{\"method\":\"mtp\",\"num_speculative_tokens\":${MTP_TOKENS:-3},\"attention_backend\":\"R4D\",\"disable_padded_drafter_batch\":true}"
        export RADIANCE_FAST_DRAFT=1 ;;
    off) ;;
    *) echo "vllm/run.sh: SPEC must be mtp or off, got '$SPEC'" >&2; exit 1 ;;
esac

[ -f "$MODEL_PATH/config.json" ] || { echo "vllm/run.sh: no model at $MODEL_PATH; run ./vllm/install.sh" >&2; exit 1; }
mkdir -p "$CACHE_PATH"

# A user unit cannot order itself after the system docker.service; wait for it.
for _ in $(seq 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
docker info >/dev/null 2>&1 || { echo "vllm/run.sh: Docker is not reachable" >&2; exit 1; }

COMPOSE=(docker compose -f "$VLLM_DIR/docker-compose.yml")
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

echo "vllm: $IMAGE, $MODEL_REPO as $SERVED_MODEL_NAME on :$PORT (KV=$KV_CACHE_MEMORY_BYTES B/card, MAX_MODEL_LEN=$MAX_MODEL_LEN, MAX_NUM_SEQS=$MAX_NUM_SEQS, SPEC=$SPEC/${MTP_TOKENS:-3}, KV scales=${FP8_KV_SCALES:-default})"
"${COMPOSE[@]}" up --no-log-prefix &
PIDS+=("$!")

wait -n
