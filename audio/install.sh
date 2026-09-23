#!/usr/bin/env bash
# audio/install.sh — clone and build qwentts.cpp, fetch its TTS models, and
# install the audio-proxy/tts-server systemd units.
#   ./audio/install.sh
set -euo pipefail

AUDIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TTS_DIR="$AUDIO_DIR/qwentts.cpp"

# Cloned separately, like llama.cpp/ — not a submodule, not committed.
if [[ -d "$TTS_DIR/.git" ]]; then
    echo "audio/install.sh: qwentts.cpp already exists at $TTS_DIR; skipping clone."
else
    git clone https://github.com/ServeurpersoCom/qwentts.cpp "$TTS_DIR"
fi

( cd "$TTS_DIR" && ./buildvulkan.sh )

# CustomVoice mode, 1.7B Q8_0: 9 built-in named speakers, no cloning needed.
mkdir -p "$TTS_DIR/models"
export PATH="$HOME/.local/bin:$PATH"
hf download Serveurperso/Qwen3-TTS-GGUF qwen-talker-1.7b-customvoice-Q8_0.gguf --local-dir "$TTS_DIR/models"
hf download Serveurperso/Qwen3-TTS-GGUF qwen-tokenizer-12hz-Q8_0.gguf --local-dir "$TTS_DIR/models"

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$UNIT_DIR"
cp "$AUDIO_DIR/cicero-tts-server.service" "$AUDIO_DIR/cicero-asr-proxy.service" "$UNIT_DIR/"
systemctl --user daemon-reload
systemctl --user enable cicero-tts-server.service cicero-asr-proxy.service
echo "audio/install.sh: done. Start with:"
echo "  systemctl --user start cicero-tts-server.service cicero-asr-proxy.service"
