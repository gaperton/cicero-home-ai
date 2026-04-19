#!/usr/bin/env bash
# bench-moe.sh — Benchmark a single MoE model on all configured backends.
#
# Usage:
#   ./bench-moe.sh [sm] [model] [mode] [backends] [pp] [tg] [ubatch]
#
#   sm         single | layer | all   (default: all)
#              single = sm=none; layer = sm=layer; all = both
#   model      path to .gguf          (default: models/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf)
#   mode       full | fitt            (default: full)
#              full = sweep n_cpu_moe 0,4,8,16,32,999
#              fitt = n_cpu_moe=999 only, run without and with --fitt 512
#   backends   csv                    (default: rocm,vulkan)
#   pp         prompt counts, csv     (default: 512,2048)
#   tg         gen counts, csv        (default: 256)
#   ubatch     ubatch sizes, csv      (default: 512,1024,2048)
#
# Env overrides:
#   BENCH_FLAGS, REPORTS_DIR, OUTFILE
#
# Examples:
#   ./bench-moe.sh
#   ./bench-moe.sh all "" fitt rocm,vulkan
#   ./bench-moe.sh single "" full rocm
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SM_ARG="${1:-all}"
MODEL="${2:-models/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf}"
MODE="${3:-full}"
BACKENDS="${4:-rocm,vulkan}"
PP_CSV="${5:-512,2048}"
TG_CSV="${6:-256}"
UB_CSV="${7:-512,1024,2048}"

case "$SM_ARG" in
    single) SPLIT_LIST=(none) ;;
    layer)  SPLIT_LIST=(layer) ;;
    all)    SPLIT_LIST=(none layer) ;;
    *) echo "Error: sm must be single, layer, or all (got '$SM_ARG')" >&2; exit 1 ;;
esac

case "$MODE" in
    full) N_CPU_MOE_LIST=(0 4 8 16 32 999) ;;
    fitt) N_CPU_MOE_LIST=(999) ;;
    *) echo "Error: mode must be full or fitt (got '$MODE')" >&2; exit 1 ;;
esac

IFS=',' read -ra BACKEND_LIST <<< "$BACKENDS"
IFS=',' read -ra PP_LIST        <<< "$PP_CSV"
IFS=',' read -ra TG_LIST        <<< "$TG_CSV"
IFS=',' read -ra UB_LIST        <<< "$UB_CSV"

BENCH_FLAGS="${BENCH_FLAGS:--ngl 99 -fa on -r 3}"
REPORTS_DIR="${REPORTS_DIR:-moe-reports}"
OUTFILE="${OUTFILE:-$REPORTS_DIR/bench-moe-$(date +%Y%m%d-%H%M%S).md}"

MODEL_LABEL="$(basename "$MODEL" .gguf)"

if [[ ! -f "$MODEL" ]]; then
    echo "Error: model not found: $MODEL" >&2
    exit 1
fi

mkdir -p "$REPORTS_DIR"

# --- Build flag arrays (same for all backends/sm) ---
moe_flags=();   for v in "${N_CPU_MOE_LIST[@]}"; do moe_flags+=(--n-cpu-moe "$v"); done
pp_flags=();    for v in "${PP_LIST[@]}";         do pp_flags+=(-p "$v");            done
tg_flags=();    for v in "${TG_LIST[@]}";         do tg_flags+=(-n "$v");            done
ub_flags=();    for v in "${UB_LIST[@]}";         do ub_flags+=(-ub "$v");           done


echo "=== MoE bench — $MODEL_LABEL — $(date) ==="
echo "Backends:    $BACKENDS"
echo "split (SM):  $SM_ARG (${SPLIT_LIST[*]})"
echo "mode:        $MODE"
echo "pp:          $PP_CSV"
echo "tg:          $TG_CSV"
echo "ubatch:      $UB_CSV"
echo "Saving to:   $OUTFILE"
echo

# Write header once
{
    echo "# MoE Benchmark — $MODEL_LABEL — $(date)"
    echo
    echo "| | |"
    echo "|---|---|"
    echo "| **Model** | $MODEL_LABEL |"
    echo "| **SM** | $SM_ARG (${SPLIT_LIST[*]}) |"
    echo "| **mode** | $MODE |"
    echo "| **pp** | $PP_CSV |"
    echo "| **tg** | $TG_CSV |"
    echo "| **ubatch** | $UB_CSV |"
    echo
} | tee "$OUTFILE"

for BACKEND in "${BACKEND_LIST[@]}"; do
    LLAMA_DIR="$SCRIPT_DIR/llama-$BACKEND"
    BENCH="$LLAMA_DIR/llama-bench"

    if [[ ! -x "$BENCH" ]]; then
        echo "Skipping $BACKEND: $BENCH not found (run update.sh $BACKEND first)" | tee -a "$OUTFILE"
        continue
    fi

    [[ "$BACKEND" == "vulkan" ]] && export RADV_DEBUG=nocompute || unset RADV_DEBUG 2>/dev/null || true

    # System info for this backend
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
        echo "## Backend: $BACKEND"
        echo
        echo "| | |"
        echo "|---|---|"
        echo "$gpu_lines"
        echo "| **RAM** | $ram |"
        echo "| **Kernel** | $kernel |"
        echo "| **llama.cpp** | $llama_ver |"
        echo
    } | tee -a "$OUTFILE"

    for SM_VAL in "${SPLIT_LIST[@]}"; do
        { echo; echo "### sm=$SM_VAL"; echo; } | tee -a "$OUTFILE"

        if [[ "$MODE" == "fitt" ]]; then
            # Run n_cpu_moe=999 without -fitt, then with -fitt 512
            for fitt_flags in "" "-fitt 512"; do
                local_label="${fitt_flags:-no -fitt}"
                { echo; echo "#### $local_label"; echo; } | tee -a "$OUTFILE"
                cmd=("$BENCH" $BENCH_FLAGS -sm "$SM_VAL" --n-cpu-moe 999 $fitt_flags "${pp_flags[@]}" "${tg_flags[@]}" "${ub_flags[@]}" -m "$MODEL" -o md)
                echo "$ ${cmd[*]}"
                echo
                "${cmd[@]}" | tee -a "$OUTFILE"
                echo | tee -a "$OUTFILE"
            done
        else
            cmd=("$BENCH" $BENCH_FLAGS -sm "$SM_VAL" "${moe_flags[@]}" "${pp_flags[@]}" "${tg_flags[@]}" "${ub_flags[@]}" -m "$MODEL" -o md)
            echo "$ ${cmd[*]}"
            echo
            "${cmd[@]}" | tee -a "$OUTFILE"
            echo | tee -a "$OUTFILE"
        fi

        echo "--- $BACKEND sm=$SM_VAL done ---"
        echo
    done
done

echo "=== Done ===" | tee -a "$OUTFILE"
