#!/usr/bin/env bash
# audio/asr-transcode-proxy.sh — run the audio-transcode proxy. See
# audio/README.md for what it does and why it's a separate service.
#
#   ./audio/asr-transcode-proxy.sh
set -euo pipefail

AUDIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$HOME/.local/share/pipx/venvs/open-webui"  # reuse: already has fastapi/httpx/uvicorn

export ASR_PROXY_UPSTREAM="${ASR_PROXY_UPSTREAM:-http://127.0.0.1:8080}"
HOST="${ASR_PROXY_HOST:-127.0.0.1}"
PORT="${ASR_PROXY_PORT:-8079}"

cd "$AUDIO_DIR"
exec "$VENV/bin/uvicorn" asr_transcode_proxy:app --host "$HOST" --port "$PORT" --log-level warning
