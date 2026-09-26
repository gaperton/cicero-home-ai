#!/usr/bin/env bash
# vllm/download-model.sh — Download or refresh MODEL_REPO into MODEL_DIR.
# Unchanged files are skipped. Called by install.sh and update.sh.
set -euo pipefail

VLLM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$VLLM_DIR")"
export PATH="$HOME/.local/bin:$PATH"
# shellcheck source=config.env
source "$VLLM_DIR/config.env"

dest="$REPO/$MODEL_DIR"
if ! hf download "$MODEL_REPO" --local-dir "$dest" --quiet; then
    # An expired stored token makes the Hub answer 401, which hf reports as
    # "Repository Not Found" even for public repos. Retry anonymously.
    echo "download-model.sh: authenticated download failed; retrying without the stored token" >&2
    echo "  (refresh it with 'hf auth login' to avoid anonymous rate limits)" >&2
    HF_HUB_DISABLE_IMPLICIT_TOKEN=1 hf download "$MODEL_REPO" --local-dir "$dest" --quiet
fi
echo "Model: $MODEL_REPO -> $dest ($(du -sh "$dest" | cut -f1))"
