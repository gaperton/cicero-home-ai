#!/usr/bin/env bash
# switch-hindsight-model.sh — switch Hindsight between the gpt-oss and gemma
# profiles, flipping the router preset and the Hindsight env file together.
#
#   ./switch-hindsight-model.sh oss     # gpt-oss-20b  — production, all operations
#   ./switch-hindsight-model.sh gemma   # gemma4-26b-a4b-qat — slower, also fine
#   ./switch-hindsight-model.sh qwen    # qwen3.6-35b-a3b Q4_K_XL (MoE, MTP)
#   ./switch-hindsight-model.sh status  # show what is currently active
#
# Two things must agree or the router thrashes, which is the whole reason this
# script exists:
#   models-1.ini                        -> models-1-{oss,gemma}.ini   (symlink)
#   ~/.config/hindsight/hindsight.env   -> hindsight-{gpt-oss,gemma}.env (symlink)
# --models-max is 2 and the reranker permanently holds one slot, so exactly one
# LLM may carry load-on-startup. If Hindsight asks for the other one, the router
# evicts and reloads on every single call.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTIVE_PRESET="$SCRIPT_DIR/models-1.ini"
CONF_DIR="$HOME/.config/hindsight"
ACTIVE_ENV="$CONF_DIR/hindsight.env"

die() { echo "error: $*" >&2; exit 1; }

link_target() {  # $1 = path -> prints basename of resolved target, or a marker
    if [[ -L "$1" ]]; then basename "$(readlink -f "$1")"
    elif [[ -f "$1" ]]; then echo "(plain file, not managed by this script)"
    else echo "(missing)"; fi
}

show_status() {
    echo "models-1.ini      -> $(link_target "$ACTIVE_PRESET")"
    echo "hindsight.env     -> $(link_target "$ACTIVE_ENV")"
    echo -n "hindsight.env model: "
    grep -E '^HINDSIGHT_API_LLM_MODEL=' "$ACTIVE_ENV" 2>/dev/null | cut -d= -f2- || echo "?"
    echo -n "running process model: "
    local pid; pid="$(pgrep -f hindsight-api | head -1 || true)"
    if [[ -n "$pid" ]]; then
        tr '\0' '\n' < "/proc/$pid/environ" | sed -n 's/^HINDSIGHT_API_LLM_MODEL=//p'
    else
        echo "(not running)"
    fi
    echo "preset load-on-startup:"
    awk '/^\[/{s=$0} /^load-on-startup/{printf "  %s\n", s}' "$ACTIVE_PRESET" 2>/dev/null
    echo "router resident:"
    curl -s http://127.0.0.1:8081/v1/models 2>/dev/null | python3 -c '
import json,sys
try:
    for m in json.load(sys.stdin)["data"]:
        print("  %-24s %s" % (m["id"], m["status"]["value"]))
except Exception:
    print("  (router not reachable)")' || echo "  (router not reachable)"
}

# Both models-1-*.ini expose their primary model under the same router id,
# [llm] (and the reranker under [reranker]), so the resident id to poll for
# below never varies by profile — only which underlying model answers "llm"
# changes, and that is entirely a function of which preset file is symlinked.
resident="llm"
case "${1:-}" in
    oss|gpt-oss|gpt-oss-20b)
        preset="models-1-oss.ini";   envfile="hindsight-gpt-oss.env"; warn=0 ;;
    gemma|gemma4|gemma4-26b|gemma4-26b-a4b-qat)
        preset="models-1-gemma.ini"; envfile="hindsight-gemma.env"; warn=1 ;;
    qwen|qwen3.6-35b|qwen35b)
        preset="models-1-qwen.ini";  envfile="hindsight-qwen.env";  warn=2 ;;
    status) show_status; exit 0 ;;
    *) die "usage: $(basename "$0") {oss|gemma|qwen|status}" ;;
esac

[[ -f "$SCRIPT_DIR/$preset" ]] || die "missing router preset: $SCRIPT_DIR/$preset"
[[ -f "$CONF_DIR/$envfile"  ]] || die "missing hindsight profile: $CONF_DIR/$envfile"

# Back up any real (non-symlink) file once before replacing it with a symlink.
for f in "$ACTIVE_PRESET" "$ACTIVE_ENV"; do
    if [[ -f "$f" && ! -L "$f" ]]; then
        cp -n "$f" "$f.pre-switch.bak" && echo "backed up $(basename "$f") -> $(basename "$f").pre-switch.bak"
    fi
done

ln -sfn "$SCRIPT_DIR/$preset" "$ACTIVE_PRESET"
ln -sfn "$CONF_DIR/$envfile"  "$ACTIVE_ENV"
echo "profile: ${1}  (models-1.ini -> $preset, hindsight.env -> $envfile)"

if (( warn == 2 )); then
    cat >&2 <<'EOF2'

NOTE: qwen3.6-35b is ALSO the benchmark's default answer+judge model on :8080.
Running it as the model under test would have it grade its own memories. The
paired .env.bench-qwen already points answer+judge at gemma4-31b instead -- use
that profile, and remember its absolute score is not comparable to runs judged
by qwen.
EOF2
fi

if (( warn == 1 )); then
    cat >&2 <<'EOF'

NOTE: the gemma profile depends on two mitigations for Reflect to terminate --
the llama.cpp patch in patches/ (re-applied by build.sh) and reasoning-budget in
models-1-gemma.ini. Both are in place; validated 40/40 Reflects on `psychology`.
It is 2-3x slower than gpt-oss (Reflect 68-83s vs 22-30s).
EOF
fi

echo
echo "restarting llama-server stack..."
systemctl --user restart cicero-home-ai.service
until curl -s http://127.0.0.1:8081/v1/models 2>/dev/null | python3 -c "
import json,sys
d={m['id']:m['status']['value'] for m in json.load(sys.stdin)['data']}
sys.exit(0 if d.get('$resident')=='loaded' and d.get('reranker')=='loaded' else 1)
" 2>/dev/null; do sleep 5; done

echo "restarting hindsight..."
systemctl --user restart hindsight.service
until curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8888/health 2>/dev/null | grep -q 200; do sleep 3; done

echo
show_status
