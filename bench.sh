#!/usr/bin/env bash
# bench.sh — Run llama-bench for all configured models.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BENCH="./llama.cpp/llama-bench"

if [[ ! -x "$BENCH" ]]; then
    echo "Error: $BENCH not found. Run install.sh or update.sh first." >&2
    exit 1
fi

# Match server flags from config.yaml: server-flags macro
BENCH_FLAGS="-ngl 99 -fa on -d 0 -r 3"

REPORTS_DIR="reports"
mkdir -p "$REPORTS_DIR"
OUTFILE="$REPORTS_DIR/bench-$(date +%Y%m%d-%H%M%S).md"

write_system_info() {
    local kernel ram llama_ver devices_info gpu_line vram_line

    # GPU, VRAM, driver — as seen by llama.cpp
    devices_info=$("$BENCH" --list-devices 2>&1)
    gpu_line=$(echo "$devices_info"  | awk '/^  (Vulkan|CUDA|ROCm|Metal)[0-9]:/{sub(/^[[:space:]]*[A-Za-z]+[0-9]+: /,""); sub(/ \([0-9]+ MiB.*$/,""); print; exit}')
    vram_line=$(echo "$devices_info" | awk '/^  (Vulkan|CUDA|ROCm|Metal)[0-9]:/{sub(/.*\(/,""); sub(/ MiB.*/,""); printf "%d GiB", $1/1024; exit}')

    # Vulkan instance version (from vulkaninfo)
    vulkan_ver=$(vulkaninfo --summary 2>/dev/null | awk '/Vulkan Instance Version/{print $NF; exit}' || echo "N/A")

    # Kernel, RAM, llama.cpp version
    kernel=$(uname -r)
    ram=$(awk '/^MemTotal:/{printf "%.0f GiB", $2/1024/1024}' /proc/meminfo)
    llama_ver=$(git -C llama.cpp log -1 --format="%h (%cd)" --date=short 2>/dev/null || echo "N/A")

    {
        echo "# Benchmark Report — $(date)"
        echo
        echo "## System Info"
        echo
        echo "| | |"
        echo "|---|---|"
        echo "| **GPU** | $gpu_line |"
        echo "| **VRAM** | $vram_line |"
        echo "| **RAM** | $ram |"
        echo "| **Kernel** | $kernel |"
        echo "| **Vulkan** | $vulkan_ver |"
        echo "| **llama.cpp** | $llama_ver |"
        echo
    } | tee -a "$OUTFILE"
}

echo "=== llama-bench — $(date) ==="
echo "Saving to: $OUTFILE"
echo

write_system_info

run_bench() {
    local label="$1"
    local model="$2"
    echo "## $label"
    echo "## $label" >> "$OUTFILE"
    "$BENCH" $BENCH_FLAGS -m "$model" -o md | tee -a "$OUTFILE"
    echo
}

run_bench "Qwen 3.5 27B · UD-Q5_K_XL" \
    "models/Qwen3.5-27B-UD-Q5_K_XL.gguf"

run_bench "Qwen 3.5 35B-A3B · UD-Q5_K_XL" \
    "models/Qwen3.5-35B-A3B-UD-Q5_K_XL.gguf"

run_bench "GLM-4.7 Flash · UD-Q5_K_XL" \
    "models/GLM-4.7-Flash-UD-Q5_K_XL.gguf"

echo "=== Done ==="