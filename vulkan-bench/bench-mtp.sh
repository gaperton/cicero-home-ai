#!/usr/bin/env bash
# bench-mtp.sh — For each Qwen 3.6 27B and Gemma 4 31B quant, autofit context
# with a Q8_0 KV cache and measure decode t/s with and without MTP
# (multi-token-prediction / self-speculative decoding).
#
# Qwen 3.6's MTP head is baked into the main gguf (qwen35.nextn_predict_layers),
# so --spec-type draft-mtp alone runs it against the target model itself.
# Gemma 4 ships its MTP head as a separate small "gemma4-assistant" gguf
# (see models/Gemma4-31B/MTP/, models/Gemma4-31B-QAT/MTP/), so those entries
# also need -md pointing at that sidecar file.
#
# llama-bench has no speculative-decoding support, so this drives llama-server
# directly: boot it with -fit on (to discover how much context fits once the
# weights + Q8 KV cache are on the GPU), then hit /completion and read
# `timings` from the JSON response (predicted_per_second, draft_n/accepted).
#
# Usage: ./bench-mtp.sh [model-substring]
#   model-substring   only run models whose label contains this (case-insensitive)
#
# Env overrides:
#   BENCH_SERVER, DEVICE, FIT_TARGET_MIB, CTK, CTV, N_PREDICT, REPEATS,
#   SPEC_DRAFT_N_MAX, PORT, REPORTS_DIR, OUTFILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LLAMA_DIR="$SCRIPT_DIR/llama.cpp"
MODELS_DIR="$SCRIPT_DIR/../models"

BENCH_SERVER="${BENCH_SERVER:-$LLAMA_DIR/build/bin/llama-server}"
DEVICE="${DEVICE:-Vulkan0}"
FIT_TARGET_MIB="${FIT_TARGET_MIB:-512}"   # VRAM margin left free per device, see -fitt
CTK="${CTK:-q8_0}"
CTV="${CTV:-q8_0}"
N_PREDICT="${N_PREDICT:-768}"  # 256*3
REPEATS="${REPEATS:-3}"
SPEC_DRAFT_N_MAX="${SPEC_DRAFT_N_MAX:-2}"  # number of tokens to draft ahead per MTP step
PORT="${PORT:-8099}"
REPORTS_DIR="${REPORTS_DIR:-reports}"
OUTFILE="${OUTFILE:-$REPORTS_DIR/bench-mtp-$(date +%Y%m%d-%H%M%S).md}"
FILTER="${1:-}"

PROMPT='Write a detailed paragraph about the history of the Roman Empire, covering its founding, expansion, and eventual fall. Then explain three lasting influences it had on modern law and government.'

if [[ ! -x "$BENCH_SERVER" ]]; then
    echo "Error: $BENCH_SERVER not found. Run init.sh first." >&2
    exit 1
fi

mkdir -p "$REPORTS_DIR"

# label|model_path|draft_path (draft_path empty = MTP head is baked into model_path)
GEMMA_MTP="$MODELS_DIR/Gemma4-31B/MTP/mtp-gemma-4-31B-it-Q8_0.gguf"
GEMMA_QAT_MTP="$MODELS_DIR/Gemma4-31B-QAT/MTP/mtp-gemma-4-31B-it-Q8_0.gguf"

MODELS=(
    "Qwen 3.6 27B · UD-Q4_K_XL|$MODELS_DIR/Qwen3.6-27B/Qwen3.6-27B-UD-Q4_K_XL.gguf|"
    "Qwen 3.6 27B · UD-Q5_K_XL|$MODELS_DIR/Qwen3.6-27B/Qwen3.6-27B-UD-Q5_K_XL.gguf|"
    "Qwen 3.6 27B · UD-Q6_K_XL|$MODELS_DIR/Qwen3.6-27B/Qwen3.6-27B-UD-Q6_K_XL.gguf|"
    "Qwen 3.6 27B · Q6_K|$MODELS_DIR/Qwen3.6-27B/Qwen3.6-27B-Q6_K.gguf|"
    "Qwen 3.6 27B · Q8_0|$MODELS_DIR/Qwen3.6-27B/Qwen3.6-27B-Q8_0.gguf|"
    "Gemma 4 31B · UD-Q5_K_XL|$MODELS_DIR/Gemma4-31B/gemma-4-31B-it-UD-Q5_K_XL.gguf|$GEMMA_MTP"
    "Gemma 4 31B · Q6_K|$MODELS_DIR/Gemma4-31B/gemma-4-31B-it-Q6_K.gguf|$GEMMA_MTP"
    "Gemma 4 31B · Q8_0|$MODELS_DIR/Gemma4-31B/gemma-4-31B-it-Q8_0.gguf|$GEMMA_MTP"
    "Gemma 4 31B QAT · UD-Q4_K_XL|$MODELS_DIR/Gemma4-31B-QAT/gemma-4-31B-it-qat-UD-Q4_K_XL.gguf|$GEMMA_QAT_MTP"
)

SERVER_PID=""
SERVER_LOG=""
FIT_CTX=""
rows_file="$(mktemp)"

cleanup() {
    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    [[ -n "$SERVER_LOG" && -f "$SERVER_LOG" ]] && rm -f "$SERVER_LOG"
    rm -f "$rows_file"
}
trap cleanup EXIT

# start_server MODEL SPEC_FLAGS -> sets SERVER_PID, SERVER_LOG, FIT_CTX
start_server() {
    local model="$1"
    local spec_flags="$2"

    SERVER_LOG="$(mktemp)"
    # shellcheck disable=SC2086
    "$BENCH_SERVER" \
        -m "$model" \
        $spec_flags \
        -ngl 99 -fa on -dev "$DEVICE" -np 1 \
        -fit on -fitt "$FIT_TARGET_MIB" -ctk "$CTK" -ctv "$CTV" \
        --port "$PORT" > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!

    local waited=0
    until curl -s -m 1 "http://127.0.0.1:$PORT/health" 2>/dev/null | grep -q '"ok"'; do
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            echo "Error: server died on startup, see log:" >&2
            cat "$SERVER_LOG" >&2
            return 1
        fi
        sleep 1
        waited=$((waited + 1))
        if [[ $waited -ge 120 ]]; then
            echo "Error: server did not become healthy within ${waited}s" >&2
            return 1
        fi
    done

    FIT_CTX=$(grep -oP 'n_ctx_slot = \K[0-9]+' "$SERVER_LOG" | head -1)
}

stop_server() {
    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    SERVER_PID=""
    [[ -n "$SERVER_LOG" && -f "$SERVER_LOG" ]] && rm -f "$SERVER_LOG"
    SERVER_LOG=""
}

# run_completion -> tab-separated: prompt_tps  predicted_tps  draft_n  draft_accepted
run_completion() {
    curl -s "http://127.0.0.1:$PORT/completion" \
        -H "Content-Type: application/json" \
        -d "{\"prompt\": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$PROMPT"), \"n_predict\": $N_PREDICT, \"temperature\": 0, \"cache_prompt\": false}" \
    | python3 -c '
import json, sys
d = json.load(sys.stdin)
t = d.get("timings", {})
pp = t.get("prompt_per_second", 0)
tg = t.get("predicted_per_second", 0)
dn = t.get("draft_n", 0)
da = t.get("draft_n_accepted", 0)
print(f"{pp:.2f}\t{tg:.2f}\t{dn}\t{da}")
'
}

# bench_mode LABEL SPEC_FLAGS -> appends a markdown row to $rows_file, returns ctx via stdout
bench_mode() {
    local label="$1"
    local spec_flags="$2"

    start_server "$model_path" "$spec_flags" || { stop_server; return 1; }
    local ctx="$FIT_CTX"

    # warmup (JIT-load KV cache, tensor caches, etc.)
    run_completion > /dev/null || true

    local pp_sum=0 tg_sum=0 draft_n_sum=0 draft_acc_sum=0
    for ((i = 0; i < REPEATS; i++)); do
        local line pp tg dn da
        line=$(run_completion || true)
        [[ -z "$line" ]] && line=$'0.00\t0.00\t0\t0'
        pp=$(echo "$line" | cut -f1)
        tg=$(echo "$line" | cut -f2)
        dn=$(echo "$line" | cut -f3)
        da=$(echo "$line" | cut -f4)
        pp_sum=$(python3 -c "print($pp_sum + $pp)")
        tg_sum=$(python3 -c "print($tg_sum + $tg)")
        draft_n_sum=$((draft_n_sum + dn))
        draft_acc_sum=$((draft_acc_sum + da))
    done
    stop_server

    local pp_avg tg_avg accept
    pp_avg=$(python3 -c "print(f'{$pp_sum / $REPEATS:.2f}')")
    tg_avg=$(python3 -c "print(f'{$tg_sum / $REPEATS:.2f}')")
    if [[ "$draft_n_sum" -gt 0 ]]; then
        accept=$(python3 -c "print(f'{100.0 * $draft_acc_sum / $draft_n_sum:.1f}%')")
    else
        accept="n/a"
    fi

    echo "| $label | $ctx | $pp_avg | $tg_avg | $accept |" >> "$rows_file"
}

# --- System info header (same shape as bench.sh) ---
write_system_info() {
    local kernel ram llama_ver devices_info gpu_lines

    devices_info=$("$BENCH_SERVER" --list-devices 2>&1)
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
        echo "# MTP Benchmark Report — $(date)"
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
        echo "| **KV cache** | K=$CTK, V=$CTV |"
        echo "| **fit target margin** | ${FIT_TARGET_MIB} MiB free |"
        echo "| **n_predict / repeats** | $N_PREDICT / $REPEATS |"
        echo "| **spec-draft-n-max** | $SPEC_DRAFT_N_MAX |"
        echo
    } | tee "$OUTFILE"
}

echo "=== MTP bench (Vulkan, $DEVICE) — $(date) ==="
echo "Saving to: $OUTFILE"
echo

write_system_info

for entry in "${MODELS[@]}"; do
    IFS='|' read -r label model_path draft_path <<< "$entry"

    if [[ -n "$FILTER" ]] && [[ "${label,,}" != *"${FILTER,,}"* ]]; then
        continue
    fi

    if [[ ! -f "$model_path" ]]; then
        echo "Skipping missing model: $model_path" | tee -a "$OUTFILE"
        continue
    fi

    if [[ -n "$draft_path" && ! -f "$draft_path" ]]; then
        echo "Skipping $label: MTP draft not found: $draft_path" | tee -a "$OUTFILE"
        continue
    fi

    mtp_flags="--spec-type draft-mtp --spec-draft-n-max $SPEC_DRAFT_N_MAX"
    [[ -n "$draft_path" ]] && mtp_flags="$mtp_flags -md $draft_path"

    echo
    echo "## $label"
    {
        echo
        echo "## $label"
        echo
        echo "| mode | autofit ctx | pp t/s | tg t/s | MTP accept rate |"
        echo "|---|---:|---:|---:|---:|"
    } >> "$OUTFILE"
    : > "$rows_file"

    echo "-- baseline (no spec) --"
    bench_mode "baseline" "" || echo "| baseline | FAILED | - | - | - |" >> "$rows_file"

    echo "-- draft-mtp --"
    bench_mode "draft-mtp" "$mtp_flags" || echo "| draft-mtp | FAILED | - | - | - |" >> "$rows_file"

    cat "$rows_file" | tee -a "$OUTFILE"
    echo >> "$OUTFILE"
done

echo "=== Done ==="
