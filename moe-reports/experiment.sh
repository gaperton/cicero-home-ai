#!/usr/bin/env bash
# experiment.sh — Run the fit / no-fit benchmark modes described in experiment.md.
#
# Usage:
#   ./moe-reports/experiment.sh [scope] [mode] [model] [backends] [pp] [tg] [ubatch]
#
# Scope:
#   single = force one GPU with -sm none -mg 0
#   all    = force split-layer across GPUs with -sm layer
#
# Mode:
#   fit        = full-VRAM test, no --n-cpu-moe
#   fit-moe    = full-VRAM test, sweep --n-cpu-moe 0,4,8,16,32,64
#   no-fit-moe = --n-cpu-moe 999, run without and with --fit-target 512
#
# Defaults:
#   model    = models/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf
#   backends = rocm,vulkan
#   pp       = 512,2048
#   tg       = 256
#   ubatch   = 512,1024,2048
#
# Env overrides:
#   BENCH_FLAGS      default: -ngl 999 -fa on -r 3 -b 2048
#   FIT_TARGET_MIB   default: 512
#   NO_FIT_N_CPU_MOE default: 999
#   REPORTS_DIR      default: moe-reports (base dir; model subdir is added automatically)
#   OUTFILE
set -euo pipefail

INVOKE_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

SCOPE="all"
MODE="fit-moe"
SCOPE="${1:-$SCOPE}"
MODE="${2:-$MODE}"
MODEL="${3:-models/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf}"
BACKENDS="${4:-rocm,vulkan}"
PP_CSV="${5:-512,2048}"
TG_CSV="${6:-256}"
UB_CSV="${7:-512,1024,2048}"

if [[ "$MODEL" != /* ]]; then
    if [[ -f "$INVOKE_DIR/$MODEL" ]]; then
        MODEL="$INVOKE_DIR/$MODEL"
    elif [[ -f "$REPO_DIR/$MODEL" ]]; then
        MODEL="$REPO_DIR/$MODEL"
    fi
fi

case "$SCOPE" in
    single)
        SPLIT_MODE="none"
        SCOPE_FLAGS=(-mg 0)
        ;;
    all)
        SPLIT_MODE="layer"
        SCOPE_FLAGS=()
        ;;
    *)
        echo "Error: scope must be single or all (got '$SCOPE')" >&2
        exit 1
        ;;
esac

FIT_TARGET_MIB="${FIT_TARGET_MIB:-512}"
NO_FIT_N_CPU_MOE="${NO_FIT_N_CPU_MOE:-999}"

case "$MODE" in
    fit)
        MODE_DESC="full VRAM, no MoE offload sweep"
        ;;
    fit-moe)
        MODE_DESC="full VRAM with --n-cpu-moe sweep"
        N_CPU_MOE_LIST=(0 4 8 16 32 64)
        N_CPU_MOE_CSV="$(IFS=,; echo "${N_CPU_MOE_LIST[*]}")"
        ;;
    no-fit-moe)
        MODE_DESC="--n-cpu-moe ${NO_FIT_N_CPU_MOE}, run without and with --fit-target"
        ;;
    *)
        echo "Error: mode must be fit, fit-moe, or no-fit-moe (got '$MODE')" >&2
        exit 1
        ;;
esac

case "$SCOPE" in
    single)
        SCOPE_TITLE="Single GPU"
        SCOPE_NOTE="Forces the model onto one GPU with \`-sm none -mg 0\`."
        ;;
    all)
        SCOPE_TITLE="All GPUs"
        SCOPE_NOTE="Uses layer split across all visible GPUs with \`-sm layer\`."
        ;;
esac

case "$MODE" in
    fit)
        MODE_TITLE="Full-VRAM Baseline"
        MODE_NOTE="Measures the baseline configuration with the model kept on GPU and no MoE CPU-offload sweep."
        ;;
    fit-moe)
        MODE_TITLE="MoE CPU-Offload Sweep"
        MODE_NOTE="Sweeps \`--n-cpu-moe\` to show how moving experts to CPU affects throughput."
        ;;
    no-fit-moe)
        MODE_TITLE="No-Fit vs Fit-Target"
        MODE_NOTE="Compares a heavy MoE CPU-offload setup with and without automatic fit-target placement."
        ;;
esac

IFS=',' read -ra BACKEND_LIST <<< "$BACKENDS"
IFS=',' read -ra PP_LIST <<< "$PP_CSV"
IFS=',' read -ra TG_LIST <<< "$TG_CSV"
IFS=',' read -ra UB_LIST <<< "$UB_CSV"

BENCH_FLAGS="${BENCH_FLAGS:--ngl 999 -fa on -r 3 -b 2048}"
MODEL_FILE="$(basename "$MODEL" .gguf)"
MODEL_STEM="$(echo "$MODEL_FILE" | sed -E 's/-[0-9]{5}-of-[0-9]{5}$//')"
MODEL_NAME="$MODEL_STEM"
QUANT_NAME="unknown"
if [[ "$MODEL_STEM" == *-UD-* ]]; then
    QUANT_SUFFIX="${MODEL_STEM##*-UD-}"
    if [[ "$QUANT_SUFFIX" =~ ^(IQ|Q)[A-Z0-9_]+$ ]]; then
        MODEL_NAME="${MODEL_STEM%-UD-*}"
        QUANT_NAME="UD-$QUANT_SUFFIX"
    fi
else
    LAST_TOKEN="${MODEL_STEM##*-}"
    if [[ "$LAST_TOKEN" =~ ^(IQ|Q)[A-Z0-9_]+$ ]]; then
        MODEL_NAME="${MODEL_STEM%-$LAST_TOKEN}"
        QUANT_NAME="$LAST_TOKEN"
    fi
fi
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DATE_HUMAN="$(date '+%Y-%m-%d %H:%M:%S %Z')"
REPORTS_BASE_DIR="${REPORTS_DIR:-$SCRIPT_DIR}"
REPORTS_DIR="$REPORTS_BASE_DIR/$MODEL_NAME"
OUTFILE="${OUTFILE:-$REPORTS_DIR/${SCOPE}-${MODE}-${QUANT_NAME}-${RUN_STAMP}.md}"

if [[ ! -f "$MODEL" ]]; then
    echo "Error: model not found: $MODEL" >&2
    exit 1
fi

mkdir -p "$REPORTS_DIR"

pp_flags=()
for value in "${PP_LIST[@]}"; do
    pp_flags+=(-p "$value")
done

tg_flags=()
for value in "${TG_LIST[@]}"; do
    tg_flags+=(-n "$value")
done

ub_flags=()
for value in "${UB_LIST[@]}"; do
    ub_flags+=(-ub "$value")
done

echo "=== Experiment bench — $MODEL_NAME — $QUANT_NAME — $(date) ==="
echo "scope:       $SCOPE"
echo "mode:        $MODE"
echo "backends:    $BACKENDS"
echo "pp:          $PP_CSV"
echo "tg:          $TG_CSV"
echo "ubatch:      $UB_CSV"
if [[ "$MODE" == "no-fit-moe" ]]; then
    echo "fit-target:  ${FIT_TARGET_MIB} MiB"
    echo "n-cpu-moe:   ${NO_FIT_N_CPU_MOE}"
fi
echo "saving to:   $OUTFILE"
echo

{
    echo "# ${SCOPE_TITLE} ${MODE_TITLE} — ${MODEL_NAME} (${QUANT_NAME})"
    echo
    echo "${SCOPE_NOTE} ${MODE_NOTE}"
    echo
    echo "- Run time: ${RUN_DATE_HUMAN}"
    echo "- Prompt sweep: \`${PP_CSV}\`"
    echo "- Generation length: \`${TG_CSV}\`"
    echo "- Ubatch sweep: \`${UB_CSV}\`"
    echo "- Core bench flags: \`${BENCH_FLAGS}\`"
    if [[ "$MODE" == "fit-moe" ]]; then
        echo "- MoE sweep: \`--n-cpu-moe ${N_CPU_MOE_CSV}\`"
    fi
    if [[ "$MODE" == "no-fit-moe" ]]; then
        echo "- MoE offload: \`--n-cpu-moe ${NO_FIT_N_CPU_MOE}\`"
        echo "- Fit target comparison: off vs \`${FIT_TARGET_MIB} MiB\`"
    fi
    echo
    echo "| | |"
    echo "|---|---|"
    echo "| **Model** | $MODEL_NAME |"
    echo "| **Quant** | $QUANT_NAME |"
    echo "| **Scope** | $SCOPE |"
    echo "| **Mode** | $MODE |"
    echo "| **Timestamp** | $RUN_DATE_HUMAN |"
    echo "| **Detail** | $MODE_DESC |"
    echo "| **pp** | $PP_CSV |"
    echo "| **tg** | $TG_CSV |"
    echo "| **ubatch** | $UB_CSV |"
    if [[ "$MODE" == "no-fit-moe" ]]; then
        echo "| **fit-target** | ${FIT_TARGET_MIB} MiB |"
        echo "| **n-cpu-moe** | ${NO_FIT_N_CPU_MOE} |"
    fi
    echo
} | tee "$OUTFILE"

for BACKEND in "${BACKEND_LIST[@]}"; do
    LLAMA_DIR="$REPO_DIR/llama-$BACKEND"
    BENCH="$LLAMA_DIR/llama-bench"

    if [[ ! -x "$BENCH" ]]; then
        echo "Skipping $BACKEND: $BENCH not found (run update.sh $BACKEND first)" | tee -a "$OUTFILE"
        continue
    fi

    if [[ "$BACKEND" == "vulkan" ]]; then
        export RADV_DEBUG=nocompute
    else
        unset RADV_DEBUG 2>/dev/null || true
    fi

    case "$BACKEND" in
        rocm)
            BACKEND_TITLE="ROCm"
            BACKEND_NOTE="AMD ROCm backend."
            ;;
        vulkan)
            BACKEND_TITLE="Vulkan"
            BACKEND_NOTE="Vulkan backend with \`RADV_DEBUG=nocompute\`."
            ;;
        *)
            BACKEND_TITLE="$BACKEND"
            BACKEND_NOTE="Benchmark results for the ${BACKEND} backend."
            ;;
    esac

    devices_info=$("$BENCH" --list-devices 2>&1)
    gpu_lines=$(echo "$devices_info" | awk '
        /^  (Vulkan|CUDA|ROCm|Metal)[0-9]:/{
            idx++
            name = $0
            sub(/^[[:space:]]*[A-Za-z]+[0-9]+: /, "", name)
            sub(/ \([0-9]+ MiB.*$/, "", name)
            vram = $0
            sub(/.*\(/, "", vram)
            sub(/ MiB.*/, "", vram)
            printf "| **GPU %d** | %s (%d GiB) |\n", idx-1, name, vram/1024
        }')
    kernel=$(uname -r)
    ram=$(awk '/^MemTotal:/{printf "%.0f GiB", $2/1024/1024}' /proc/meminfo)
    llama_ver=$(git -C "$LLAMA_DIR" log -1 --format="%h (%cd)" --date=short 2>/dev/null || echo "N/A")

    {
        echo "## ${BACKEND_TITLE}"
        echo
        echo "${BACKEND_NOTE}"
        echo
        echo "| | |"
        echo "|---|---|"
        echo "$gpu_lines"
        echo "| **RAM** | $ram |"
        echo "| **Kernel** | $kernel |"
        echo "| **llama.cpp** | $llama_ver |"
        echo
    } | tee -a "$OUTFILE"

    if [[ "$MODE" == "fit" ]]; then
        { echo; echo "### Baseline Run"; echo; } | tee -a "$OUTFILE"
        cmd=("$BENCH" $BENCH_FLAGS -sm "$SPLIT_MODE" "${SCOPE_FLAGS[@]}" "${pp_flags[@]}" "${tg_flags[@]}" "${ub_flags[@]}" -m "$MODEL" -o md)
        echo "$ ${cmd[*]}"
        echo
        "${cmd[@]}" | tee -a "$OUTFILE"
        echo | tee -a "$OUTFILE"
        echo "--- $BACKEND $SCOPE $MODE done ---"
        echo
        continue
    fi

    if [[ "$MODE" == "fit-moe" ]]; then
        {
            echo
            echo "### MoE CPU-Offload Sweep"
            echo
            echo "Sweeping \`--n-cpu-moe\` across \`${N_CPU_MOE_CSV}\` while keeping the rest of the benchmark settings fixed."
            echo
        } | tee -a "$OUTFILE"
        cmd=("$BENCH" $BENCH_FLAGS -sm "$SPLIT_MODE" "${SCOPE_FLAGS[@]}" --n-cpu-moe "$N_CPU_MOE_CSV" "${pp_flags[@]}" "${tg_flags[@]}" "${ub_flags[@]}" -m "$MODEL" -o md)
        echo "$ ${cmd[*]}"
        echo
        "${cmd[@]}" | tee -a "$OUTFILE"
        echo | tee -a "$OUTFILE"
        echo "--- $BACKEND $SCOPE $MODE done ---"
        echo
        continue
    fi

    for FIT_FLAGS in "" "-fitt $FIT_TARGET_MIB"; do
        LABEL="No Fit Target"
        NOTE="Runs \`--n-cpu-moe ${NO_FIT_N_CPU_MOE}\` without automatic fitting."
        if [[ -n "$FIT_FLAGS" ]]; then
            LABEL="With Fit Target ${FIT_TARGET_MIB} MiB"
            NOTE="Runs \`--n-cpu-moe ${NO_FIT_N_CPU_MOE}\` with \`-fitt ${FIT_TARGET_MIB}\`."
        fi
        {
            echo
            echo "### ${LABEL}"
            echo
            echo "${NOTE}"
            echo
        } | tee -a "$OUTFILE"
        cmd=("$BENCH" $BENCH_FLAGS -sm "$SPLIT_MODE" "${SCOPE_FLAGS[@]}" --n-cpu-moe "$NO_FIT_N_CPU_MOE" $FIT_FLAGS "${pp_flags[@]}" "${tg_flags[@]}" "${ub_flags[@]}" -m "$MODEL" -o md)
        echo "$ ${cmd[*]}"
        echo
        "${cmd[@]}" | tee -a "$OUTFILE"
        echo | tee -a "$OUTFILE"
    done

    echo "--- $BACKEND $SCOPE $MODE done ---"
    echo
done

echo "=== Done ===" | tee -a "$OUTFILE"
