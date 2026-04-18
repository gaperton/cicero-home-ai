#!/usr/bin/env bash
# bench-moe.sh — Benchmark a single MoE model with a cartesian product of split modes × n-cpu-moe values.
#                0 in n-cpu-moe list means no CPU MoE offload (baseline).
#
# Usage:
#   ./bench-moe.sh [vulkan|rocm] [model_path] [n_cpu_moe_csv] [split_csv] [pp_csv] [tg_csv]
#
# Examples:
#   ./bench-moe.sh rocm models/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf 0,4,8,16,32,999 none,layer 512,2048 256
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKEND="${1:-vulkan}"
MODEL="${2:-models/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf}"
N_CPU_MOE_CSV="${3:-0,4,8,16,32,999}"
SPLIT_CSV="${4:-none,layer}"
PP_CSV="${5:-512,2048}"
TG_CSV="${6:-256}"
UB_CSV="${7:-512,1024,2048}"
B_CSV="${8:-2048,4096}"

IFS=',' read -ra N_CPU_MOE_LIST <<< "$N_CPU_MOE_CSV"
IFS=',' read -ra SPLIT_LIST    <<< "$SPLIT_CSV"
IFS=',' read -ra PP_LIST       <<< "$PP_CSV"
IFS=',' read -ra TG_LIST       <<< "$TG_CSV"
IFS=',' read -ra UB_LIST       <<< "$UB_CSV"
IFS=',' read -ra B_LIST        <<< "$B_CSV"

LLAMA_DIR="$SCRIPT_DIR/llama-$BACKEND"
[[ "$BACKEND" == "vulkan" ]] && export RADV_DEBUG=nocompute

BENCH="${BENCH:-$LLAMA_DIR/llama-bench}"
BENCH_FLAGS="${BENCH_FLAGS:--ngl 99 -fa on -r 3}"
REPORTS_DIR="${REPORTS_DIR:-moe-reports}"
OUTFILE="${OUTFILE:-$REPORTS_DIR/bench-moe-$(date +%Y%m%d-%H%M%S).md}"

if [[ ! -x "$BENCH" ]]; then
    echo "Error: $BENCH not found. Run update.sh $BACKEND first." >&2
    exit 1
fi

if [[ ! -f "$MODEL" ]]; then
    echo "Error: model not found: $MODEL" >&2
    exit 1
fi

mkdir -p "$REPORTS_DIR"

MODEL_LABEL="$(basename "$MODEL" .gguf)"

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
        echo "# MoE Benchmark — $MODEL_LABEL — $(date)"
        echo
        echo "## System Info"
        echo
        echo "| | |"
        echo "|---|---|"
        echo "$gpu_lines"
        echo "| **RAM** | $ram |"
        echo "| **Kernel** | $kernel |"
        echo "| **Backend** | $BACKEND |"
        echo "| **llama.cpp** | $llama_ver |"
        echo
    } | tee "$OUTFILE"
}

echo "=== MoE bench — $MODEL_LABEL — $(date) ==="
echo "Backend:     $BACKEND"
echo "split:       $SPLIT_CSV"
echo "n-cpu-moe:   $N_CPU_MOE_CSV"
echo "pp:          $PP_CSV"
echo "tg:          $TG_CSV"
echo "ubatch:      $UB_CSV"
echo "batch:       $B_CSV"
echo "Saving to:   $OUTFILE"
echo

write_system_info

# Build repeated -sm and --n-cpu-moe flags for one cartesian-product invocation
sm_flags=()
for sm in "${SPLIT_LIST[@]}"; do
    sm_flags+=(-sm "$sm")
done

moe_flags=()
for n in "${N_CPU_MOE_LIST[@]}"; do
    moe_flags+=(--n-cpu-moe "$n")
done

pp_flags=()
for p in "${PP_LIST[@]}"; do
    pp_flags+=(-p "$p")
done

tg_flags=()
for t in "${TG_LIST[@]}"; do
    tg_flags+=(-n "$t")
done

ub_flags=()
for u in "${UB_LIST[@]}"; do
    ub_flags+=(-ub "$u")
done

b_flags=()
for b in "${B_LIST[@]}"; do
    b_flags+=(-b "$b")
done

{ echo; echo "## $MODEL_LABEL"; } >> "$OUTFILE"
cmd=("$BENCH" $BENCH_FLAGS "${sm_flags[@]}" "${moe_flags[@]}" "${pp_flags[@]}" "${tg_flags[@]}" "${ub_flags[@]}" "${b_flags[@]}" -m "$MODEL" -o md)
echo "$ ${cmd[*]}"
echo
"${cmd[@]}" | tee -a "$OUTFILE"

echo "=== Done ==="
