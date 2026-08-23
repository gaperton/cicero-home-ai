#!/usr/bin/env bash
# bench-mtp.sh — A/B multi-token prediction (MTP / self-speculative decoding)
# on the Hindsight workload, for the models that can serve as Hindsight's LLM.
#
# This exists to settle one standing question, recorded in CLAUDE.md: "MTP
# remains disabled unless exact Hindsight end-to-end benchmarks prove it is not
# slower for the prompt-heavy workload." The old version of this script could
# not answer it — it sent a 40-token prompt and generated 768 tokens, tuned
# nothing to the deployment, and measured a workload nobody runs.
#
# The workload here is instead reconstructed from the 480 real gpt-oss-20b calls
# the `psychology` bank recorded in Hindsight's `llm_requests` table, and it
# does not look like the old "prefill dominates" section in
# ../experiments/2026-08-installation-and-tuning-log.md claims:
#
#   op             calls  %LLM time  in p50   cached  out p50/avg  concurrency
#   consolidation   369      53%      5,493    44%     255 / 294    1.06 avg
#   retain           77      34%      2,365    64%     596 / 611    2.45 avg
#   reflect          33      13%     14,369     n/r     82 / 446    1.33 avg
#
# Retain is small-prompt and generation-heavy, not a 23k-token prefill job;
# Reflect is the only large-prompt operation and it is 7% of calls. Across the
# whole recorded mix, uncached prefill is ~430 s of work against ~1,270 s of
# decode at this machine's rates — decode-dominated, i.e. the regime where MTP
# can actually pay. That is why the question is worth re-measuring rather than
# settling from the old Qwen figures (MTP raised decode 109.5 -> 134.1 tok/s
# while dropping prefill 368.7 -> 312.9).
#
# hindsight-load.py drives it, reproducing the rest of the deployment: real
# system prompts (read from llm_requests, falling back to templates/), strict
# JSON schemas on Retain and Consolidation, a shared cached system prefix with
# a freshly generated payload per request, per-operation concurrency from the
# recorded overlap, and no client-side sampling except Retain's 0.1.
#
# Thinking: gpt-oss reasons at effort=low (its native bound, and what Hindsight
# sends); every other model runs with thinking off, so its capped output budget
# goes to the answer rather than to reasoning. See NO_THINK below.
#
# **Read the `mix, per 100 calls` row.** It weights each profile's burst by that
# operation's share of recorded calls and is the number the MTP decision turns
# on. `burst` per profile is the per-operation view; per-request pp/tg are
# diagnostics. A row where tg goes up and the mix goes up is MTP losing.
#
# Each model runs with an embedded, model-specific profile (slots, ctx, batch,
# KV type, chat template, temp). The deployed gpt-oss settings track
# gpu-0-1/combined.ini; alternate profiles remain benchmark-only candidates.
#
# The Qwen models are A/B'd. Both bake their MTP head into the main gguf
# (qwen35.nextn_predict_layers=1, verified in each checkpoint), so --spec-type
# draft-mtp alone runs it against the target model itself. The rest run
# baseline-only:
#   - gpt-oss-20b, the deployed Hindsight LLM, has no MTP head and no sidecar
#     draft. It is here as the reference the alternates have to beat.
#   - Gemma 4 does ship an MTP head as a separate small "gemma4-assistant" gguf,
#     but it is not measured here. The presets record the dense 31B at 6.5x
#     slower prefill and 6.7x slower decode than gpt-oss at Hindsight's prompt
#     sizes (Retain 41.8 s end to end against 4.3 s) — a gap no draft depth
#     closes. Gemma stays as a baseline reference row only. To measure it
#     again, put the sidecar path back in the draft field of its MODELS entry.
# Nemotron 3.5 Lightning bakes its head in the same way
# (nemotron_h_moe.nextn_predict_layers=1, blk.52.nextn.* present) and is A/B'd
# too — verified by booting it with --spec-type draft-mtp, which logs "creating
# MTP draft context against the target model" rather than falling back.
#
# NOTE ON MEASUREMENT HYGIENE: an unloaded card is not an idle test bed. Stop
# cicero-home-ai.service and hindsight.service first — the script warns if they
# are up, and prints GTT before each run, since a large GTT spill (not VRAM) is
# what silently halved throughput in earlier contaminated runs. This bench also
# runs the LLM alone on the card, while production shares GPU1 with the
# resident reranker; absolute numbers are therefore optimistic, the A/B is not.
#
# Usage: ./bench-mtp.sh [model-substring]
#   model-substring   only run models whose label contains this (case-insensitive)
#
# Env overrides:
#   BENCH_SERVER, DEVICE, FIT_TARGET_MIB, PROFILES, CONCURRENCY, REPEATS,
#   WARMUP, SPEC_DRAFT_N_MAX, EXTRA_SERVER_FLAGS, PORT, REPORTS_DIR, OUTFILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$SCRIPT_DIR"

LLAMA_DIR="$REPO_ROOT/llama.cpp"
MODELS_DIR="$REPO_ROOT/models"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
LOADER="$SCRIPT_DIR/hindsight-load.py"

BENCH_SERVER="${BENCH_SERVER:-$LLAMA_DIR/llama-server}"
DEVICE="${DEVICE:-ROCm1}"          # Hindsight's card
FIT_TARGET_MIB="${FIT_TARGET_MIB:-512}"
PROFILES="${PROFILES:-retain consolidate reflect}"   # also available: reflect-long (p90)
# Empty = each profile uses its own measured average overlap (1 / 2 / 1). Set
# it to 3 to study the saturated case (HINDSIGHT_API_LLM_MAX_CONCURRENT); the
# mix row stays comparable because it divides the burst by the concurrency.
CONCURRENCY="${CONCURRENCY:-}"
REPEATS="${REPEATS:-3}"
WARMUP="${WARMUP:-1}"
SPEC_DRAFT_N_MAX="${SPEC_DRAFT_N_MAX:-2}"  # tokens drafted ahead per MTP step
EXTRA_SERVER_FLAGS="${EXTRA_SERVER_FLAGS:-}"
PORT="${PORT:-8099}"
REPORTS_DIR="${REPORTS_DIR:-reports}"
OUTFILE="${OUTFILE:-$REPORTS_DIR/bench-mtp-$(date +%Y%m%d-%H%M%S).md}"
FILTER="${1:-}"

# Hindsight's HINDSIGHT_API_LLM_EXTRA_BODY. reasoning_effort is gpt-oss's own
# output-bounding mechanism and reaches the harmony template only through
# chat_template_kwargs; it is a no-op for the other models, which is correct —
# Hindsight sends it to all of them.
LLM_EXTRA_BODY_DEFAULT='{"chat_template_kwargs":{"reasoning_effort":"low"}}'
LLM_EXTRA_BODY="${LLM_EXTRA_BODY:-$LLM_EXTRA_BODY_DEFAULT}"

if [[ ! -x "$BENCH_SERVER" ]]; then
    echo "Error: $BENCH_SERVER not found. Run $REPO_ROOT/build.sh first." >&2
    exit 1
fi
if [[ ! -f "$LOADER" ]]; then
    echo "Error: $LOADER not found." >&2
    exit 1
fi

mkdir -p "$REPORTS_DIR"

# Thinking policy, and the one place this bench deliberately departs from the
# presets. gpt-oss reasons at effort=low — it cannot be switched off, low is
# its native output bound, it is what Hindsight sends, and the experiment log records
# that raising it is net worse end to end. It rides in LLM_EXTRA_BODY above.
#
# Every other model has thinking turned OFF here. `-rea off` sets
# enable_thinking=false as a default template kwarg (common/arg.cpp), which:
#   - Qwen 3.6 honours — its template is `enable_thinking is defined and is
#     false`, i.e. thinking is ON by default, so without this Qwen would spend
#     most of its capped output budget on reasoning instead of the answer;
#   - Gemma 4 already defaults to (`enable_thinking | default(false)`), so the
#     flag only makes the intent explicit there.
# Note this is a bench-only choice: Hindsight sends no enable_thinking, so a
# Qwen deployed as its LLM would think. Drop `$NO_THINK` from a model's flags
# to measure that instead.
NO_THINK="-rea off"

# label|model|draft|server_flags
# server_flags preserve the model profiles used for the earlier comparisons.
# Anything omitted (batch/ubatch on the Gemma dense model, for instance) is
# deliberate and measured net-negative.
# Deployed gpt-oss [llm] profile (expanded to three slots for this isolated bench).
GPTOSS_FLAGS="-np 3 -c 393216 -b 4096 -ub 2048 -ctk f16 -ctv f16 --temp 0.2 --chat-template-file $TEMPLATES_DIR/gpt-oss-20b-harmony.jinja"
# The dense 31B is not deployed as Hindsight's LLM. These are its old [llm]
# flags, kept unchanged so this
# baseline row stays comparable with the earlier reports in reports/.
GEMMA31_FLAGS="-np 2 -c 200000 -ctk q8_0 -ctv q8_0 --temp 1.0 --top-p 0.95 --top-k 64 --min-p 0.0 --presence-penalty 0 $NO_THINK"
# Gemma 26B candidate. --reasoning-budget is REQUIRED, not tuning: without it
# a forced tool turn can collapse into an unbounded generation that holds a slot
# past the client timeout. See ../experiments/gemma4.md.
GEMMA26_FLAGS="-np 3 -c 300000 -ctk f16 -ctv f16 --temp 0.2 --top-p 0.95 --top-k 64 --min-p 0.0 --presence-penalty 0 --reasoning-budget 1024 $NO_THINK"
# Qwen Hindsight-candidate shape; this intentionally differs from the active
# chat profile in gpu-0-1/combined.ini.
QWEN38_FLAGS="-np 2 -c 200000 -b 4096 -ub 2048 -ctk q8_0 -ctv q8_0 --temp 0.2 --top-p 0.95 --top-k 20 --min-p 0.0 --presence-penalty 0 $NO_THINK"
# Qwen 3.5 candidate.
QWEN35_FLAGS="-np 2 -c 200000 -b 4096 -ub 2048 -ctk q8_0 -ctv q8_0 --temp 0.2 --top-p 0.95 --top-k 20 --min-p 0.0 --presence-penalty 0 $NO_THINK"
# No preset yet. Hybrid Mamba/attention MoE (nemotron_h_moe, 128 experts, 6
# active + 1 shared), so it borrows the qwen3.6-35b-a3b profile's slot/ctx/KV
# budget; sampling left at llama.cpp defaults apart from temp, since this
# model's recommended params are not established here. q8_0 KV verified to boot
# on the hybrid arch. Replace with a real preset before quoting its numbers as
# deployable.
NEMOTRON_FLAGS="-np 2 -c 200000 -b 4096 -ub 2048 -ctk q8_0 -ctv q8_0 --temp 0.2 $NO_THINK"

MODELS=(
    "gpt-oss-20b · UD-Q8_K_XL (deployed, baseline only)|$MODELS_DIR/GPT-OSS-20B/gpt-oss-20b-UD-Q8_K_XL.gguf||$GPTOSS_FLAGS"
    "gemma4-31b-qat · UD-Q4_K_XL (baseline only)|$MODELS_DIR/Gemma4-31B-QAT/gemma-4-31B-it-qat-UD-Q4_K_XL.gguf||$GEMMA31_FLAGS"
    "gemma4-26b-a4b-qat · UD-Q4_K_XL (baseline only)|$MODELS_DIR/Gemma4-26B-A4B-QAT/gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf||$GEMMA26_FLAGS"
    "qwen3.8-27b · UD-Q4_K_XL|$MODELS_DIR/Qwen3.8-27B/Qwen3.8-27B-UD-Q4_K_XL.gguf||$QWEN38_FLAGS"
    "qwen3.6-35b-a3b · UD-Q4_K_XL|$MODELS_DIR/Qwen3.6-35B-A3B/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf||$QWEN35_FLAGS"
    "nemotron3.5-lightning-30b-a3b · UD-IQ4_NL|$MODELS_DIR/Nemotron-3.5-Lightning/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-UD-IQ4_NL.gguf||$NEMOTRON_FLAGS"
)

# Models whose MTP head is baked into the main gguf: no -md, but they still
# support --spec-type draft-mtp. Anything else with an empty draft field runs
# baseline-only — gpt-oss-20b because it has no head, Gemma by choice. Both Qwen
# checkpoints carry qwen35.nextn_predict_layers=1, hence the family-wide glob;
# Nemotron carries nemotron_h_moe.nextn_predict_layers=1.
has_baked_mtp() { [[ "$1" == qwen3.* || "$1" == nemotron3.* ]]; }

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

gtt_used() {
    local total=0 used
    for f in /sys/class/drm/card*/device/mem_info_gtt_used; do
        [[ -r "$f" ]] || continue
        read -r used < "$f"
        total=$((total + used))
    done
    awk -v b="$total" 'BEGIN{printf "%.2f GiB", b/1073741824}'
}

preflight() {
    local busy=()
    for svc in cicero-home-ai.service hindsight.service; do
        systemctl is-active --quiet "$svc" 2>/dev/null && busy+=("$svc")
    done
    if [[ ${#busy[@]} -gt 0 ]]; then
        echo "WARNING: ${busy[*]} still running — the cards are not idle and these"
        echo "         numbers will not be comparable to earlier reports. Stop them first."
        echo
    fi
    echo "GTT in use before first load: $(gtt_used)"
    echo
}

# start_server MODEL SERVER_FLAGS SPEC_FLAGS -> sets SERVER_PID, SERVER_LOG, FIT_CTX
start_server() {
    local model="$1" preset_flags="$2" spec_flags="$3"

    SERVER_LOG="$(mktemp)"
    # Shared production-style defaults, plus the two flags every model
    # section sets. --cache-ram -1 is not cosmetic: llama.cpp defaults to an
    # 8192 MiB prompt cache, and this workload leans on the host-RAM cache to
    # keep the Retain and Consolidation system prefixes alive while the two
    # alternate on the same slot (see README.md). --repeat-penalty 1.0 matches
    # llama.cpp's own default but is stated explicitly per CLAUDE.md, and
    # because llama.cpp's gpt-oss guide is emphatic that penalties break it.
    # kv-unified is left unset in both places: it defaults on only when the
    # slot count is auto, and -np is always explicit here.
    # shellcheck disable=SC2086 — flags are intentionally word-split
    "$BENCH_SERVER" \
        -m "$model" \
        $preset_flags $spec_flags $EXTRA_SERVER_FLAGS \
        -ngl 99 -fa on -dev "$DEVICE" --jinja --no-mmap --cont-batching \
        --cache-ram -1 --repeat-penalty 1.0 \
        -fit on -fitt "$FIT_TARGET_MIB" \
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
        if [[ $waited -ge 180 ]]; then
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

# bench_mode MODE_LABEL SPEC_FLAGS — one server boot, every profile through it
bench_mode() {
    local mode="$1" spec_flags="$2"

    if ! start_server "$model_path" "$preset_flags" "$spec_flags"; then
        stop_server
        for profile in $PROFILES; do
            echo "| $profile | $mode | SERVER FAILED | - | - | - | - | - | - | - |" >> "$rows_file"
        done
        return 1
    fi
    echo "   n_ctx_slot=$FIT_CTX  GTT=$(gtt_used)"

    local mix_acc=0 share_acc=0
    for profile in $PROFILES; do
        local line mode_note conc_flag=()
        [[ -n "$CONCURRENCY" ]] && conc_flag=(--concurrency "$CONCURRENCY")
        line=$(python3 "$LOADER" --profile "$profile" --port "$PORT" "${conc_flag[@]}" \
                   --repeats "$REPEATS" --warmup "$WARMUP" \
                   --templates-dir "$TEMPLATES_DIR" --extra-body "$LLM_EXTRA_BODY" || true)
        if [[ -z "$line" ]]; then
            echo "| $profile | $mode | FAILED | - | - | - | - | - | - | - |" >> "$rows_file"
            continue
        fi
        # prompt_n cache_n pp tg predicted_n burst_wall agg_pp accept errors conc share
        IFS=$'\t' read -r p_n c_n pp tg gen wall agg accept errs conc share <<< "$line"
        [[ "${errs:-0}" != "0" ]] && mode_note="$mode (${errs} err)" || mode_note="$mode"
        echo "| $profile | $mode_note | ${p_n}+${c_n} | $pp | $agg | $tg | $gen | ${conc} | **$wall** | $accept |" \
            >> "$rows_file"
        # Seconds of LLM time per 100 calls of the recorded operation mix: the
        # single number the MTP decision turns on. wall covers `conc` requests.
        mix_acc=$(python3 -c "print(f'{$mix_acc + 100.0 * $share * $wall / $conc:.2f}')")
        share_acc=$(python3 -c "print(f'{$share_acc + $share:.2f}')")
    done

    # The decision row: extrapolated LLM seconds per 100 Hindsight calls at the
    # recorded operation mix (77% consolidation / 16% retain / 7% reflect).
    # Meaningful only if the profiles that ran cover most of that mix.
    if [[ "$(python3 -c "print(1 if $share_acc >= 0.9 else 0)")" == "1" ]]; then
        echo "| **mix, per 100 calls** | $mode | - | - | - | - | - | - | **${mix_acc}s** | - |" \
            >> "$rows_file"
    fi

    stop_server
}

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
        echo "# MTP Benchmark Report (Hindsight workload) — $(date)"
        echo
        echo "## System Info"
        echo
        echo "| | |"
        echo "|---|---|"
        echo "$gpu_lines"
        echo "| **RAM** | $ram |"
        echo "| **Kernel** | $kernel |"
        echo "| **llama.cpp** | $llama_ver |"
        echo "| **Backend** | ROCm ($DEVICE) |"
        echo "| **Workload** | psychology-bank shape: $PROFILES |"
        echo "| **Concurrency** | ${CONCURRENCY:-per profile, from recorded overlap} |"
        echo "| **warmup / repeats** | $WARMUP / $REPEATS bursts |"
        echo "| **spec-draft-n-max** | $SPEC_DRAFT_N_MAX |"
        echo "| **KV / batch / slots** | embedded per-model profiles |"
        echo "| **extra body** | \`$LLM_EXTRA_BODY\` |"
        echo "| **thinking** | gpt-oss: effort=low; all others: \`$NO_THINK\` |"
        echo
        echo "Prompt sizes, output lengths, cache-hit shares and concurrency are"
        echo "derived from 480 recorded \`llm_requests\` rows of the \`psychology\`"
        echo "bank. \`burst\` is the wall time of one concurrent round; the"
        echo "\`mix, per 100 calls\` row weights those by operation share and is"
        echo "the figure that maps to Hindsight's LLM time. Error counts include"
        echo "the warm-up burst, which is excluded from every timing."
        echo
    } | tee "$OUTFILE"
}

echo "=== MTP bench on the Hindsight workload (ROCm, $DEVICE) — $(date) ==="
echo "Saving to: $OUTFILE"
echo
preflight
write_system_info

for entry in "${MODELS[@]}"; do
    IFS='|' read -r label model_path draft_path preset_flags <<< "$entry"

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

    echo
    echo "## $label"
    {
        echo
        echo "## $label"
        echo
        echo "\`$preset_flags\`"
        echo
        echo "| profile | mode | prompt tok (new+cached) | pp t/s | agg pp t/s | tg t/s | gen tok | conc | burst | MTP accept |"
        echo "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"
    } >> "$OUTFILE"
    : > "$rows_file"

    echo "-- baseline (no spec) --"
    bench_mode "baseline" "" || true

    if [[ -n "$draft_path" ]] || has_baked_mtp "$label"; then
        mtp_flags="--spec-type draft-mtp --spec-draft-n-max $SPEC_DRAFT_N_MAX"
        [[ -n "$draft_path" ]] && mtp_flags="$mtp_flags -md $draft_path"
        echo "-- draft-mtp --"
        bench_mode "draft-mtp" "$mtp_flags" || true
    else
        echo "-- draft-mtp: not measured for this model --"
        for profile in $PROFILES; do
            echo "| $profile | draft-mtp | not measured | - | - | - | - | - | - | - |" >> "$rows_file"
        done
    fi

    cat "$rows_file" | tee -a "$OUTFILE"
    echo >> "$OUTFILE"
done

echo "=== Done ==="
