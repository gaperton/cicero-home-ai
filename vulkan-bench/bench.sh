#!/usr/bin/env bash
# bench.sh — Run llama-bench on a single GPU via the Vulkan backend, for the
# 27B and 31B-QAT models, to compare against the ROCm build in ../benchmark.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LLAMA_DIR="$SCRIPT_DIR/llama.cpp"
MODELS_DIR="$SCRIPT_DIR/../models"

BENCH="${BENCH:-$LLAMA_DIR/llama-bench}"
DEVICE="${DEVICE:-Vulkan0}"
BENCH_FLAGS="${BENCH_FLAGS:--ngl 99 -fa on -r 3}"
REPORTS_DIR="${REPORTS_DIR:-reports}"
OUTFILE="${OUTFILE:-$REPORTS_DIR/bench-$(date +%Y%m%d-%H%M%S).md}"

if [[ ! -x "$BENCH" ]]; then
    echo "Error: $BENCH not found. Run init.sh first." >&2
    exit 1
fi

mkdir -p "$REPORTS_DIR"

MODELS=(
    "Qwen 3.6 27B · Q8_0|$MODELS_DIR/Qwen3.6-27B/Qwen3.6-27B-Q8_0.gguf"
    "Qwen 3.6 27B · UD-Q5_K_XL|$MODELS_DIR/Qwen3.6-27B/Qwen3.6-27B-UD-Q5_K_XL.gguf"
    "Gemma 4 31B QAT · UD-Q4_K_XL|$MODELS_DIR/Gemma4-31B-QAT/gemma-4-31B-it-qat-UD-Q4_K_XL.gguf"
)

write_system_info() {
    local kernel ram llama_ver devices_info gpu_lines

    devices_info=$("$BENCH" --list-devices 2>&1)
    gpu_lines=$(echo "$devices_info" | awk '
        /^  (Vulkan|CUDA|ROCm|Metal)[0-9]:/{
            idx++
            name = $0; sub(/^[[:space:]]*[A-Za-z]+[0-9]+: /, "", name); sub(/ \([0-9]+ MiB.*$/, "", name)
            vram = $0; sub(/.*\(/, "", vram); sub(/ MiB.*/, "", vram)
            printf "| **GPU %d** | %s (%d GiB) |\n", idx-1, name, vram/1024
        }')

    kernel=$(uname -r)
    ram=$(awk '/^MemTotal:/{printf "%.0f GiB", $2/1024/1024}' /proc/meminfo)
    llama_ver=$(git -C "$LLAMA_DIR" log -1 --format="%h (%cd)" --date=short 2>/dev/null || echo "N/A")

    {
        echo "# Vulkan Benchmark Report — $(date)"
        echo
        echo "## System Info"
        echo
        echo "| | |"
        echo "|---|---|"
        echo "$gpu_lines"
        echo "| **RAM** | $ram |"
        echo "| **Kernel** | $kernel |"
        echo "| **llama.cpp** | $llama_ver |"
        echo "| **Backend** | Vulkan ($DEVICE) |"
        echo
    } | tee "$OUTFILE"
}

run_bench_section() {
    local heading="$1"
    local model="$2"

    if [[ ! -f "$model" ]]; then
        echo "Skipping missing model: $model" | tee -a "$OUTFILE"
        return
    fi

    echo
    echo "$heading"
    {
        echo
        echo "$heading"
    } >> "$OUTFILE"

    "$BENCH" $BENCH_FLAGS -dev "$DEVICE" -m "$model" -o md | tee -a "$OUTFILE"
    echo >> "$OUTFILE"
}

echo "=== llama-bench (Vulkan, $DEVICE) — $(date) ==="
echo "Saving to: $OUTFILE"
echo

write_system_info

for entry in "${MODELS[@]}"; do
    label="${entry%%|*}"
    model="${entry##*|}"

    run_bench_section "## $label · $DEVICE" "$model"
done

echo "=== Done ==="
