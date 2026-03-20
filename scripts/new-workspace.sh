#!/usr/bin/env bash
# Create a new workspace (session) with sidebar.

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SIDEBAR_WIDTH=18

read -p "Workspace name: " name
[ -z "$name" ] && exit 0

tmux new-session -d -s "$name" 2>/dev/null || { echo "Session '$name' exists"; sleep 1; exit 1; }

# Add sidebar
sidebar=$(tmux split-window -hb -t "$name:1" -l "$SIDEBAR_WIDTH" \
  -PF '#{pane_id}' "$SCRIPTS_DIR/sidebar.sh $name")
tmux set-option -p -t "$sidebar" @tmux-ws-role sidebar 2>/dev/null
tmux select-pane -t "$name:1.2" 2>/dev/null

tmux switch-client -t "$name"
