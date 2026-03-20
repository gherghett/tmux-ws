#!/usr/bin/env bash
# Create a new workspace (session) with sidebar. Auto-names if no name given.

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SIDEBAR_WIDTH=18

# Auto-generate name: ws-1, ws-2, etc.
n=1
while tmux has-session -t "ws-$n" 2>/dev/null; do
  ((n++))
done
name="ws-$n"

tmux new-session -d -s "$name"

sidebar=$(tmux split-window -hb -t "$name:1" -l "$SIDEBAR_WIDTH" \
  -PF '#{pane_id}' "$SCRIPTS_DIR/sidebar.sh $name")
tmux set-option -p -t "$sidebar" @tmux-ws-role sidebar 2>/dev/null
tmux select-pane -t "$name:1.2" 2>/dev/null

tmux switch-client -t "$name"
