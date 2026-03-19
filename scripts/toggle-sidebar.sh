#!/usr/bin/env bash
# Toggle the workspace sidebar pane

SIDEBAR_MARKER="TMUX_WS_SIDEBAR"
sidebar_pane=""

# Find existing sidebar pane
for pane_id in $(tmux list-panes -F '#{pane_id}' 2>/dev/null); do
  cmd=$(tmux display-message -t "$pane_id" -p '#{pane_current_command}' 2>/dev/null)
  start_cmd=$(tmux display-message -t "$pane_id" -p '#{pane_start_command}' 2>/dev/null)
  if echo "$start_cmd" | grep -q "sidebar.sh"; then
    sidebar_pane="$pane_id"
    break
  fi
done

if [ -n "$sidebar_pane" ]; then
  tmux kill-pane -t "$sidebar_pane"
else
  # Create sidebar: split left, 32 cols wide, run sidebar script
  tmux split-window -hbdl 32 "$HOME/.tmux/scripts/sidebar.sh"
fi
