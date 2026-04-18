#!/usr/bin/env bash
# download-quants.sh — Download Q4_K_XL, Q5_K_XL, Q6_K_XL UD quants from unsloth for a model.
#
# Usage: ./download-quants.sh <ModelName>
#   e.g. ./download-quants.sh Qwen3.5-27B
#        ./download-quants.sh gemma-4-31B-it
#
# Downloads from unsloth/<ModelName>-GGUF into models/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="$HOME/.local/bin:$PATH"

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <ModelName>" >&2
    echo "  e.g. $0 Qwen3.5-27B" >&2
    exit 1
fi

MODEL="$1"
REPO="unsloth/${MODEL}-GGUF"

for quant in Q4_K_XL Q5_K_XL Q6_K_XL; do
    file="${MODEL}-UD-${quant}.gguf"
    echo "==> $REPO / $file"
    hf download "$REPO" "$file" --local-dir models/
done
