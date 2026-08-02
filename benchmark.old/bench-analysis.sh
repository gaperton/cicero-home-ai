#!/usr/bin/env bash
# bench-analysis.sh — Run the standard analysis benchmark for a given model.
#
# Usage: ./bench-analysis.sh [--moe] [--fitt] <model.gguf> [<model2.gguf> ...]
#
# Runs with sm=layer at pp512/2048/4096 + tg256.
# All quants write into one file: analysis/<model-name>-<timestamp>.md
# Model name is derived from the first argument by stripping the quant suffix (-UD-Q*).
#
# Overrides:
#   BENCH   path to llama-bench   (default: ../llama.cpp/llama-bench)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BENCH="${BENCH:-../llama.cpp/llama-bench}"

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

BENCH_FLAGS="$BENCH_FLAGS -sm layer"

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--moe] [--fitt] <model.gguf> [<model2.gguf> ...]" >&2
    exit 1
fi

if [[ ! -x "$BENCH" ]]; then
    echo "Error: $BENCH not found. Run build.sh first." >&2
    exit 1
fi

mkdir -p analysis

# Derive report name from first model: strip quant suffix (-UD-Q* or -Q*)
first_label="$(basename "$1" .gguf)"
model_name="${first_label%-UD-Q*}"
model_name="${model_name%-Q*}"
outfile="analysis/${model_name}-$(date +%Y%m%d-%H%M%S).md"

{
    echo "# $model_name — Analysis Benchmark"
    echo
    echo "**Date:** $(date)  "
    echo "**Flags:** \`$BENCH_FLAGS\`"
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

    echo "## $label · sm=layer" | tee -a "$outfile"
    "$BENCH" $BENCH_FLAGS -m "$model" -o md 2>&1 | tee -a "$outfile" \
        || echo "**ERROR: bench crashed (exit ${PIPESTATUS[0]})**" | tee -a "$outfile"
    echo >> "$outfile"
done

echo "=== Done: $outfile ==="
