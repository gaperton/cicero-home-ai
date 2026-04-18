#!/usr/bin/env bash
# bench-analysis.sh — Run the standard multi-backend analysis benchmark for a given model.
#
# Usage: ./bench-analysis.sh [--moe] [--fitt] <model.gguf> [<model2.gguf> ...]
#
# Runs ROCm with sm=layer and Vulkan with sm=none at pp512/2048/4096 + tg256.
# All quants write into one file: analysis/<model-name>-<timestamp>.md
# Model name is derived from the first argument by stripping the quant suffix (-UD-Q*).
#
# Overrides:
#   ROCM_BENCH   path to ROCm llama-bench   (default: ./llama-rocm/llama-bench)
#   VULKAN_BENCH path to Vulkan llama-bench  (default: ./llama-vulkan/llama-bench)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ROCM_BENCH="${ROCM_BENCH:-./llama-rocm/llama-bench}"
VULKAN_BENCH="${VULKAN_BENCH:-./llama-vulkan/llama-bench}"

BENCH_FLAGS="-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2"

MOE=0
args=()
for arg in "$@"; do
    if [[ "$arg" == "--moe" ]]; then
        MOE=1
        BENCH_FLAGS="$BENCH_FLAGS --n-cpu-moe 999 -b 4096 -ub 4096"
    elif [[ "$arg" == "--fitt" ]]; then
        BENCH_FLAGS="$BENCH_FLAGS -fitt 512"
    else
        args+=("$arg")
    fi
done
set -- "${args[@]+"${args[@]}"}"

ROCM_BENCH_FLAGS="$BENCH_FLAGS -sm layer"
VULKAN_BENCH_FLAGS="$BENCH_FLAGS -sm none"

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--moe] [--fitt] <model.gguf> [<model2.gguf> ...]" >&2
    exit 1
fi

mkdir -p analysis

run_bench() {
    local bin="$1" flags="$2"; shift 2
    RADV_DEBUG=nocompute "$bin" $flags "$@"
}

# Derive report name from first model: strip quant suffix (-UD-Q* or -Q*)
first_label="$(basename "$1" .gguf)"
model_name="${first_label%-UD-Q*}"
model_name="${model_name%-Q*}"
outfile="analysis/${model_name}-$(date +%Y%m%d-%H%M%S).md"

{
    echo "# $model_name — Analysis Benchmark"
    echo
    echo "**Date:** $(date)  "
    echo "**ROCm flags:** \`$ROCM_BENCH_FLAGS\`  "
    echo "**Vulkan flags:** \`$VULKAN_BENCH_FLAGS\`  "
    echo "**Env:** \`RADV_DEBUG=nocompute\`"
    echo
} | tee "$outfile"

echo "Saving to: $outfile"
echo

for model in "$@"; do
    if [[ ! -f "$model" ]]; then
        echo "Skipping missing model: $model" | tee -a "$outfile"
        continue
    fi

    label="$(basename "$model" .gguf)"

    if [[ -x "$ROCM_BENCH" ]]; then
        echo "## $label · ROCm · sm=layer" | tee -a "$outfile"
        run_bench "$ROCM_BENCH" "$ROCM_BENCH_FLAGS" -m "$model" -o md 2>&1 | tee -a "$outfile" \
            || echo "**ERROR: ROCm bench crashed (exit ${PIPESTATUS[0]})**" | tee -a "$outfile"
        echo >> "$outfile"
    else
        echo "ROCm bench not found at $ROCM_BENCH, skipping." | tee -a "$outfile"
    fi

    if [[ -x "$VULKAN_BENCH" ]]; then
        echo "## $label · Vulkan · sm=none" | tee -a "$outfile"
        run_bench "$VULKAN_BENCH" "$VULKAN_BENCH_FLAGS" -m "$model" -o md 2>&1 | tee -a "$outfile" \
            || echo "**ERROR: Vulkan bench crashed (exit ${PIPESTATUS[0]})**" | tee -a "$outfile"
        echo >> "$outfile"
    else
        echo "Vulkan bench not found at $VULKAN_BENCH, skipping." | tee -a "$outfile"
    fi
done

echo "=== Done: $outfile ==="
