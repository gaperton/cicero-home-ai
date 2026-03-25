#!/usr/bin/env bash
# run.sh — Update llama.cpp & models, then start llama-server in router mode.
#   ./run.sh          # run directly
#   See run-tmux.sh   # run in tmux with mc
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

bash update.sh

docker compose up -d
trap 'docker compose down' EXIT

./llama.cpp/llama-server \
    --host 0.0.0.0 --port 8080 \
    --models-preset models.ini \
    --models-max 1
