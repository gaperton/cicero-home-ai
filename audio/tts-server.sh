#!/usr/bin/env bash
# audio/tts-server.sh — run the resident TTS server (CustomVoice 1.7B, Q8_0)
# from audio/qwentts.cpp (cloned/built by audio/install.sh). See
# audio/README.md for the model/voice choice and GPU placement.
#
#   ./audio/tts-server.sh
set -euo pipefail

AUDIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$AUDIO_DIR/qwentts.cpp"

PORT="${TTS_SERVER_PORT:-8078}"
MAX_BATCH="${TTS_SERVER_MAX_BATCH:-4}"

# RUNPATH in build/tts-server is absolute and breaks if this checkout moves;
# LD_LIBRARY_PATH doesn't have that problem.
export LD_LIBRARY_PATH="$PWD/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Pinned to ROCm1 (see audio/README.md) so it doesn't compete with ROCm0's
# router models for VRAM.
export GGML_VK_VISIBLE_DEVICES=1

./build/tts-server \
    --model models/qwen-talker-1.7b-customvoice-Q8_0.gguf \
    --codec models/qwen-tokenizer-12hz-Q8_0.gguf \
    --alias qwen3-tts-customvoice \
    --host 127.0.0.1 \
    --port "$PORT" \
    --max-batch "$MAX_BATCH" &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null' EXIT

wait "$SERVER_PID"
