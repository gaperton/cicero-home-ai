#!/usr/bin/env bash
# bench-combined.sh — bench-mtp's Hindsight workload, but driven against the LIVE
# combined router instead of a server this script spawns.
#
# bench-mtp.sh answers "how fast is this model, alone, on one card, under these
# flags". That is the wrong question for gpu-0-1: there the models share two cards,
# each in its own split mode, with the others resident and competing. This measures
# what the deployment actually delivers, so the numbers are directly comparable to
# a saved bench-mtp report from the one-router-per-card era.
#
# The services must be UP — that is the whole point.
#   ./bench-combined.sh                 # both models
#   ./bench-combined.sh qwen3.8-27b     # one
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT="${PORT:-8081}"
REPEATS="${REPEATS:-3}"
WARMUP="${WARMUP:-1}"
CONCURRENCY="${CONCURRENCY:-}"      # empty = each profile's own recorded overlap
PROFILES="${PROFILES:-retain consolidate reflect}"
REPORTS_DIR="${REPORTS_DIR:-reports}"
OUTFILE="${OUTFILE:-$REPORTS_DIR/bench-combined-$(date +%Y%m%d-%H%M%S).md}"
FILTER="${1:-}"

# model id -> the extra_body Hindsight would send it. gpt-oss bounds its own output
# with reasoning_effort; the Qwen family needs thinking switched off explicitly,
# which is what bench-mtp's `-rea off` does at the server level.
declare -A EXTRA=(
  [llm]='{"chat_template_kwargs":{"reasoning_effort":"low"}}'
  [qwen3.8-27b]='{"chat_template_kwargs":{"enable_thinking":false}}'
)
ORDER=(llm qwen3.8-27b)

curl -s --max-time 5 "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1 || {
    echo "Error: no router on :$PORT — start the services first (../start.sh)." >&2; exit 1; }

mkdir -p "$REPORTS_DIR"
rows="$(mktemp)"; trap 'rm -f "$rows"' EXIT

{
    echo "# Combined-router Benchmark (Hindsight workload) — $(date)"
    echo
    echo "| | |"
    echo "|---|---|"
    echo "| **Router** | live gpu-0-1 on :$PORT, all models resident |"
    echo "| **llama.cpp** | $(git -C ../llama.cpp log -1 --format='%h (%cd)' --date=short 2>/dev/null || echo N/A) |"
    echo "| **warmup / repeats** | $WARMUP / $REPEATS bursts |"
    echo "| **Concurrency** | ${CONCURRENCY:-per profile, from recorded overlap} |"
    for f in ../gpu-0-1/active.ini; do echo "| **Preset** | $(basename "$(readlink -f "$f")") |"; done
    echo
    echo "\`burst\` is the wall time of one concurrent round. \`mix, per 100 calls\`"
    echo "weights those by the recorded operation share (16 retain at concurrency 2,"
    echo "77 consolidate, 7 reflect) and is the figure that maps to Hindsight's LLM time."
    echo
} | tee "$OUTFILE"

for model in "${ORDER[@]}"; do
    [[ -n "$FILTER" && "$model" != *"$FILTER"* ]] && continue
    { echo; echo "## $model"; echo
      echo "| profile | prompt tok (new+cached) | pp t/s | **agg pp** | tg t/s | **agg tg** | gen tok | conc | burst | MTP accept | err |"
      echo "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"; } | tee -a "$OUTFILE"
    : > "$rows"
    for p in $PROFILES; do
        line=$(python3 hindsight-load.py --profile "$p" --port "$PORT" --model "$model" \
                 --repeats "$REPEATS" --warmup "$WARMUP" \
                 ${CONCURRENCY:+--concurrency "$CONCURRENCY"} \
                 --extra-body "${EXTRA[$model]}" 2>/dev/null | tail -1)
        IFS=$'\t' read -r pn cn pp tg gen burst aggpp aggtg acc err conc share <<< "$line"
        echo "$p $burst $conc" >> "$rows"
        printf '| %s | %s+%s | %s | **%s** | %s | **%s** | %s | %s | **%s** | %s | %s |\n' \
            "$p" "$pn" "$cn" "$pp" "$aggpp" "$tg" "$aggtg" "$gen" "$conc" "$burst" "$acc" "$err" | tee -a "$OUTFILE"
    done
    # Each profile's share divided by the concurrency it actually ran at: a burst of
    # N concurrent calls retires N calls, so 77 consolidations at concurrency 2 cost
    # 77/2 bursts. Hardcoding /2 for retain only is correct at the recorded overlap
    # (2/1/1) and WRONG whenever CONCURRENCY forces the others above 1.
    mixv=$(awk '{b[$1]=$2; c[$1]=$3} END {printf "%.2f",
                 16/c["retain"]*b["retain"] + 77/c["consolidate"]*b["consolidate"] + 7/c["reflect"]*b["reflect"]}' "$rows")
    printf '| **mix, per 100 calls** | - | - | - | - | - | - | - | **%ss** | - | - |\n' "$mixv" | tee -a "$OUTFILE"
done
echo; echo "Saved: $OUTFILE"
