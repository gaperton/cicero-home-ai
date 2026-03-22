#!/usr/bin/env bash
# run-tmux.sh — Start llama-swap in a tmux session.
#   ./run-tmux.sh        # start or attach
#   ./run-tmux.sh kill   # stop the session
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SESSION_NAME="llama-swap"

# Kill the session if requested
if [ "${1:-}" = "kill" ]; then
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || echo "No session to kill."
    exit 0
fi

# Attach if already running
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

# Create tmux session: llama-server (left) | mc (right)
tmux new-session -d -s "$SESSION_NAME" -n main
tmux split-window -h -t "$SESSION_NAME:main"

tmux send-keys -t "$SESSION_NAME:main.0" "cd '$SCRIPT_DIR' && bash run.sh" C-m
tmux send-keys -t "$SESSION_NAME:main.1" "mc" C-m

tmux select-pane -t "$SESSION_NAME:main.0"
tmux attach-session -t "$SESSION_NAME"
