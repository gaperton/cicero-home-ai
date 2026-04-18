#!/usr/bin/env bash
# bench.sh — Run one combined benchmark report: GPU 0, GPU 1, split=layer, split=row for all configured models.
#   ./bench.sh [vulkan|rocm]   # backend defaults to vulkan
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKEND="${1:-vulkan}"

LLAMA_DIR="$SCRIPT_DIR/llama-$BACKEND"
[[ "$BACKEND" == "vulkan" ]] && export RADV_DEBUG=nocompute


BENCH="${BENCH:-$LLAMA_DIR/llama-bench}"
BENCH_FLAGS="${BENCH_FLAGS:--ngl 99 -fa on -r 3}"
REPORTS_DIR="${REPORTS_DIR:-reports}"
OUTFILE="${OUTFILE:-$REPORTS_DIR/bench-$(date +%Y%m%d-%H%M%S).md}"

if [[ ! -x "$BENCH" ]]; then
    echo "Error: $BENCH not found. Run update.sh $BACKEND first." >&2
    exit 1
fi

mkdir -p "$REPORTS_DIR"

MODELS=(
    "Qwen 3.5 27B · UD-Q5_K_XL|models/Qwen3.5-27B-UD-Q5_K_XL.gguf"
    "Qwen 3.6 35B-A3B · UD-Q5_K_XL|models/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf"
    "Gemma 4 31B · UD-Q5_K_XL|models/gemma-4-31B-it-UD-Q5_K_XL.gguf"
)

write_system_info() {
    local kernel ram llama_ver vulkan_ver devices_info gpu_lines

    devices_info=$("$BENCH" --list-devices 2>&1)
    gpu_lines=$(echo "$devices_info" | awk '
        /^  (Vulkan|CUDA|ROCm|Metal)[0-9]:/{
            idx++
            name = $0; sub(/^[[:space:]]*[A-Za-z]+[0-9]+: /, "", name); sub(/ \([0-9]+ MiB.*$/, "", name)
            vram = $0; sub(/.*\(/, "", vram); sub(/ MiB.*/, "", vram)
            printf "| **GPU %d** | %s (%d GiB) |\n", idx-1, name, vram/1024
        }')

    vulkan_ver=$(vulkaninfo --summary 2>/dev/null | awk '/Vulkan Instance Version/{print $NF; exit}' || echo "N/A")
    kernel=$(uname -r)
    ram=$(awk '/^MemTotal:/{printf "%.0f GiB", $2/1024/1024}' /proc/meminfo)
    llama_ver=$(git -C "$LLAMA_DIR" log -1 --format="%h (%cd)" --date=short 2>/dev/null || echo "N/A")

    {
        echo "# Benchmark Report — $(date)"
        echo
        echo "## System Info"
        echo
        echo "| | |"
        echo "|---|---|"
        echo "$gpu_lines"
        echo "| **RAM** | $ram |"
        echo "| **Kernel** | $kernel |"
        echo "| **Vulkan** | $vulkan_ver |"
        echo "| **llama.cpp** | $llama_ver |"
        echo
    } | tee "$OUTFILE"
}

run_bench_section() {
    local heading="$1"
    shift
    local model="${@: -1}"

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

    "$BENCH" $BENCH_FLAGS "$@" -o md | tee -a "$OUTFILE"
    echo >> "$OUTFILE"
}

echo "=== llama-bench — $(date) ==="
echo "Saving to: $OUTFILE"
echo

write_system_info

for entry in "${MODELS[@]}"; do
    label="${entry%%|*}"
    model="${entry##*|}"

    run_bench_section "## $label · GPU 0 only" -dev Vulkan0 -m "$model"    run_bench_section "## $label · GPU 1 only" -dev Vulkan1 -m "$model"    run_bench_section "## $label · split=layer" -sm layer -m "$model"    run_bench_section "## $label · split=row" -sm row -m "$model"done

echo "=== Done ==="