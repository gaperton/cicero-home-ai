#!/usr/bin/env bash
# audio/tts-server.sh — run the resident TTS server (1.7B base, Q8_0) on the
# GPU via Vulkan, from the qwentts.cpp checkout in audio/qwentts.cpp (cloned
# and built by audio/install.sh). Kept in its own systemd unit, independent of
# cicero-home-ai.service and cicero-asr-proxy.service.
#
# Also registers examples/freeman.* as a named cloned voice on every start:
# base mode has no built-in speakers and voice registration is in-memory only
# (tools/tts-server.cpp, g_voices), so it does not survive a restart on its
# own. audio/asr_transcode_proxy.py defaults every /v1/audio/speech request
# without a valid voice to this one (DEFAULT_TTS_VOICE), for a consistent
# cloned identity instead of base mode's emergent per-call timbre.
#
#   ./audio/tts-server.sh
set -euo pipefail

AUDIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$AUDIO_DIR/qwentts.cpp"

PORT="${TTS_SERVER_PORT:-8078}"
MAX_BATCH="${TTS_SERVER_MAX_BATCH:-4}"

# build/tts-server links against build/libggml*.so with an absolute RUNPATH
# baked in at cmake time; that path breaks the moment this checkout moves
# (e.g. this reorg). Set LD_LIBRARY_PATH instead of relying on it/rebuilding.
export LD_LIBRARY_PATH="$PWD/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# max-batch > 1 is real GPU batching (src/pipeline-tts.h: persistent
# [hidden, max_batch] KV tensors, not just a deeper queue) - default 1
# serializes concurrent requests entirely (observed: 3 concurrent requests
# took 2.68s total = sum of individual latencies, zero overlap).
./build/tts-server \
    --model models/qwen-talker-1.7b-base-Q8_0.gguf \
    --codec models/qwen-tokenizer-12hz-Q8_0.gguf \
    --alias qwen3-tts-base \
    --host 127.0.0.1 \
    --port "$PORT" \
    --max-batch "$MAX_BATCH" &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null' EXIT

until curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$PORT/v1/models"; do
    sleep 1
done
curl -s -X POST "http://127.0.0.1:$PORT/v1/audio/voices" -H "Content-Type: application/json" \
    -d "{\"name\":\"freeman\",\"ref_text\":\"$(cat examples/freeman.txt)\",\"spk_b64\":\"$(base64 -w0 examples/freeman.spk)\",\"rvq_b64\":\"$(base64 -w0 examples/freeman.rvq)\"}" \
    > /dev/null

wait "$SERVER_PID"
