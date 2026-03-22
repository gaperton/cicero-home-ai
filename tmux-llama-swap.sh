#!/usr/bin/env bash
#
# tmux-llama-swap.sh
# Creates/attaches to a tmux session with this layout:
#
#   ┌──────────────────────────────┬──────────────────────────────┐
#   │ llama-swap --config          │ mc (Midnight Commander)      │
#   │   config.yaml                │                              │
#   │                              │                              │
#   └──────────────────────────────┴──────────────────────────────┘
#

SESSION_NAME="llama-swap"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$1" = "kill" ]; then
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || echo "No session to kill."
    exit 0
fi

# If session already exists → attach to it
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

# Create new detached session
tmux new-session -d -s "$SESSION_NAME" -n main

# Split the window vertically → left and right panes
tmux split-window -h -t "$SESSION_NAME:main"

# Left pane: llama-swap
tmux send-keys -t "$SESSION_NAME:main.0" "cd '$SCRIPT_DIR' && llama-swap --config config.yaml" C-m

# Right pane: Midnight Commander
tmux send-keys -t "$SESSION_NAME:main.1" "mc" C-m

# Focus on the left pane
tmux select-pane -t "$SESSION_NAME:main.1"

# Attach to the session
tmux attach-session -t "$SESSION_NAME"
