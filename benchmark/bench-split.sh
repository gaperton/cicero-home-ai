#!/usr/bin/env bash
# bench-split.sh — How much does splitting a model across both cards actually buy?
#
# Runs llama-bench over the same model three ways:
#   single  one card, -sm none      — the classic layout of this repo
#   layer   both cards, -sm layer   — pipelined, one card idle at a time
#   tensor  both cards, -sm tensor  — parallel weights + KV (EXPERIMENTAL upstream)
#
# One model at a time, nothing else resident — this measures the backend, not the
# combined router. Stop the services first (the script refuses otherwise): an
# unloaded card is not an idle test bed, and a model that spills into GTT
# measures the PCIe bus rather than the GPU, so GTT is sampled around every run.
#
# Both halves of the workload are covered: -p is prefill, -n is decode, and -d
# repeats each at depth so the RDNA4 prefill-at-depth regression (llama.cpp#26220)
# shows up instead of hiding behind a cold 512-token prompt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LLAMA_DIR="$SCRIPT_DIR/../llama.cpp"
MODELS_DIR="$SCRIPT_DIR/../models"

BENCH="${BENCH:-$LLAMA_DIR/llama-bench}"
BENCH_FLAGS="${BENCH_FLAGS:--ngl 99 -fa on -r 3}"
PROMPTS="${PROMPTS:-512,4096}"
GENS="${GENS:-128}"
DEPTHS="${DEPTHS:-0,16384}"
REPORTS_DIR="${REPORTS_DIR:-reports}"
OUTFILE="${OUTFILE:-$REPORTS_DIR/bench-split-$(date +%Y%m%d-%H%M%S).md}"

[[ -x "$BENCH" ]] || { echo "Error: $BENCH not found. Run ../build.sh first." >&2; exit 1; }

if systemctl --user is-active --quiet cicero-home-ai.service; then
    echo "Error: cicero-home-ai.service is running — it holds both cards." >&2
    echo "  Run ../stop.sh first, and ../start.sh when the benchmark finishes." >&2
    exit 1
fi

mkdir -p "$REPORTS_DIR"

MODELS=(
    "Qwen 3.8 27B · UD-Q5_K_M|$MODELS_DIR/Qwen3.8-27B/Qwen3.8-27B-UD-Q5_K_M.gguf"
    "GPT-OSS 20B · UD-Q8_K_XL|$MODELS_DIR/GPT-OSS-20B/gpt-oss-20b-UD-Q8_K_XL.gguf"
)

# label|device list|split mode
# NOTE the SLASH in the device lists. llama-bench's -dev takes <dev0/dev1/...>,
# and a COMMA there means "run one more test", exactly as it does in -p 512,4096.
# `-dev ROCm0,ROCm1` therefore silently benchmarks each card on its own and emits
# two single-GPU rows that look like a split but are not one.
CONFIGS=(
    "single|ROCm0|none"
    "layer|ROCm0/ROCm1|layer"
    "tensor|ROCm0/ROCm1|tensor"
)

gtt_used() {  # summed across both cards, MiB
    rocm-smi --showmeminfo gtt 2>/dev/null \
        | awk '/Used/ {gsub(/[^0-9]/,"",$NF); s+=$NF} END {printf "%.0f", s/1024/1024}'
}

write_system_info() {
    local kernel ram llama_ver gpu_lines
    gpu_lines=$("$BENCH" --list-devices 2>&1 | awk '
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
        echo "# Split-mode Benchmark — $(date)"
        echo
        echo "| | |"
        echo "|---|---|"
        echo "$gpu_lines"
        echo "| **RAM** | $ram |"
        echo "| **Kernel** | $kernel |"
        echo "| **llama.cpp** | $llama_ver |"
        echo "| **Backend** | ROCm |"
        echo "| **Flags** | \`$BENCH_FLAGS -p $PROMPTS -n $GENS -d $DEPTHS\` |"
        echo
    } | tee "$OUTFILE"
}

echo "=== split-mode bench — $(date) ==="
echo "Saving to: $OUTFILE"
write_system_info

for entry in "${MODELS[@]}"; do
    label="${entry%%|*}"; model="${entry##*|}"
    if [[ ! -f "$model" ]]; then
        echo "Skipping missing model: $model" | tee -a "$OUTFILE"
        continue
    fi
    { echo; echo "## $label"; } | tee -a "$OUTFILE"

    for cfg in "${CONFIGS[@]}"; do
        IFS='|' read -r cfg_label devs sm <<< "$cfg"
        gtt_before=$(gtt_used)
        { echo; echo "### $cfg_label — \`-dev $devs -sm $sm\`"; echo; } | tee -a "$OUTFILE"

        # shellcheck disable=SC2086
        "$BENCH" $BENCH_FLAGS -dev "$devs" -sm "$sm" \
            -p "$PROMPTS" -n "$GENS" -d "$DEPTHS" -m "$model" -o md 2>&1 | tee -a "$OUTFILE"

        gtt_after=$(gtt_used)
        # A GTT jump means weights or KV spilled to host memory over PCIe; the
        # numbers above then describe the bus, not the card. Flag it in the report.
        if (( gtt_after - gtt_before > 512 )); then
            echo "" | tee -a "$OUTFILE"
            echo "> **GTT grew ${gtt_before} -> ${gtt_after} MiB — this run spilled to host memory; treat these numbers as invalid.**" | tee -a "$OUTFILE"
        fi
        echo >> "$OUTFILE"
    done
done

echo "=== Done: $OUTFILE ==="
