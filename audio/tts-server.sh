#!/usr/bin/env bash
# audio/tts-server.sh — run the resident TTS server (1.7B CustomVoice, Q8_0)
# on the GPU via Vulkan, from the qwentts.cpp checkout in audio/qwentts.cpp
# (cloned and built by audio/install.sh). Kept in its own systemd unit,
# independent of cicero-home-ai.service and cicero-asr-proxy.service.
#
# CustomVoice ships 9 built-in named speakers baked into the model weights
# (serena, vivian, uncle_fu, ryan, aiden, ono_anna, sohee, eric, dylan — the
# last two carry Mandarin dialect overrides), selected per-request via the
# "voice" field, no registration or reference audio needed. This replaced the
# base-mode model, which had zero built-in speakers and needed a cloned
# reference voice (examples/freeman.*) registered over HTTP on every start to
# get a consistent identity; tools/tts-server.cpp refuses /v1/audio/voices
# registration outright on a non-base model, so that step is gone too.
# audio/asr_transcode_proxy.py defaults every /v1/audio/speech request
# without a valid voice to DEFAULT_TTS_VOICE ("aiden").
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

# Vulkan device 1 == ROCm1 (confirmed via VkPhysicalDevicePCIBusInfoPropertiesEXT:
# Vulkan0 is PCI bus 0x0A, Vulkan1 is 0x0D, matching rocm-smi --showbus's GPU[0]/
# GPU[1] exactly). Pinned here so gpu-0-1's router presets can load qwen3-asr and
# qwen3-reranker onto ROCm0 without competing with this process for VRAM — see
# gpu-0-1/qwen3-asr.ini. Without this, ggml-vulkan defaults to device 0 (ROCm0).
export GGML_VK_VISIBLE_DEVICES=1

# max-batch > 1 is real GPU batching (src/pipeline-tts.h: persistent
# [hidden, max_batch] KV tensors, not just a deeper queue) - default 1
# serializes concurrent requests entirely (observed: 3 concurrent requests
# took 2.68s total = sum of individual latencies, zero overlap).
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
