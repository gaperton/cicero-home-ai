#!/usr/bin/env bash
# vllm/start.sh — Start cicero-vllm.service and wait until the API answers.
# Starting it stops the llama.cpp stack and the TTS server (Conflicts= in the unit).
set -euo pipefail

VLLM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$VLLM_DIR/config.env"

systemctl --user start cicero-vllm.service
echo "Starting (a cold compile cache takes ~5 minutes) ..."
for _ in $(seq 360); do
    if curl -sf -m 2 "http://127.0.0.1:$PORT/health" >/dev/null; then
        echo "Ready: http://127.0.0.1:$PORT/v1 ($SERVED_MODEL_NAME)"
        exit 0
    fi
    systemctl --user is-active --quiet cicero-vllm.service || break
    sleep 5
done
echo "error: not ready; see logs/vllm.log" >&2
exit 1
