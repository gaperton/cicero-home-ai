#!/usr/bin/env bash
# audio/install.sh — clone and build qwentts.cpp, fetch its TTS models, and
# install the audio-proxy/tts-server systemd units. Run once (or again after
# deleting audio/qwentts.cpp to force a clean re-clone).
#   ./audio/install.sh
set -euo pipefail

AUDIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$AUDIO_DIR")"
TTS_DIR="$AUDIO_DIR/qwentts.cpp"

# qwentts.cpp is cloned separately, like llama.cpp/ — not a submodule, not
# committed, rebuilt from scratch by this script.
if [[ -d "$TTS_DIR/.git" ]]; then
    echo "audio/install.sh: qwentts.cpp checkout already exists at $TTS_DIR; skipping clone."
else
    git clone https://github.com/ServeurpersoCom/qwentts.cpp "$TTS_DIR"
fi

# Vulkan build: the TTS server shares neither the ROCm/HIP toolchain nor the
# build/ directory used by llama.cpp.
( cd "$TTS_DIR" && ./buildvulkan.sh )

# Model weights (talker + shared tokenizer, base mode 1.7B Q8_0) from the
# GGUF conversion of upstream's checkpoints; qwentts.cpp/models/ is gitignored.
mkdir -p "$TTS_DIR/models"
export PATH="$HOME/.local/bin:$PATH"
hf download Serveurperso/Qwen3-TTS-GGUF qwen-talker-1.7b-base-Q8_0.gguf --local-dir "$TTS_DIR/models"
hf download Serveurperso/Qwen3-TTS-GGUF qwen-tokenizer-12hz-Q8_0.gguf --local-dir "$TTS_DIR/models"

# Install/update both audio systemd units. Same sed-portable pattern as
# gpu-0-1/install-service.sh: the units hardcode /home/gaperton/cicero-home-ai
# so they read cleanly on the machine they're meant for, substituted here for
# wherever this checkout actually lives.
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$UNIT_DIR"
for unit in cicero-tts-server.service cicero-asr-proxy.service; do
    sed "s|/home/gaperton/cicero-home-ai|$REPO|g" "$AUDIO_DIR/$unit" > "$UNIT_DIR/$unit"
done
systemctl --user daemon-reload
systemctl --user enable cicero-tts-server.service cicero-asr-proxy.service
echo "audio/install.sh: done. Start with:"
echo "  systemctl --user start cicero-tts-server.service cicero-asr-proxy.service"
