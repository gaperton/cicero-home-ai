#!/usr/bin/env bash
# models/install.sh — Install everything needed to download/update models. Run once.
# Self-contained: installs pipx too, so this works standalone without the top-level install.sh.
#   ./models/install.sh
set -euo pipefail

if ! command -v pipx >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y pipx
fi

pipx install huggingface_hub[cli]
pipx ensurepath

echo "Reload your shell so 'hf' is on PATH, then run 'hf auth login' and ./models/update.sh"
