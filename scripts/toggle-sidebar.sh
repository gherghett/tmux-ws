#!/usr/bin/env bash
# Toggle sidebar in the current window.
# Finds sidebar by @tmux-ws-role option — no heuristic scanning.

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SIDEBAR_WIDTH=18

# Find sidebar pane in current window by @tmux-ws-role
sidebar_pane=""
while IFS='|' read -r pane_id role; do
  if [ "$role" = "sidebar" ]; then
    sidebar_pane="$pane_id"
    break
  fi
done < <(tmux list-panes -F '#{pane_id}|#{@tmux-ws-role}' 2>/dev/null)

if [ -n "$sidebar_pane" ]; then
  tmux kill-pane -t "$sidebar_pane"
else
  SESSION=$(tmux display-message -p '#S')
  sidebar=$(tmux split-window -hb -l "$SIDEBAR_WIDTH" \
    -PF '#{pane_id}' "$SCRIPTS_DIR/sidebar.sh $SESSION")
  tmux set-option -p -t "$sidebar" @tmux-ws-role sidebar 2>/dev/null
  tmux select-pane -l 2>/dev/null  # focus back to previous pane
fi
