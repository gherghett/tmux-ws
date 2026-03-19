#!/usr/bin/env bash
# Interactive workspace picker using fzf

chosen=$(tmux list-sessions -F '#{session_name} (#{session_windows} tabs) #{?session_attached,← attached,}' 2>/dev/null \
  | fzf --reverse --height=40% \
        --header="Switch workspace (ESC to cancel)" \
        --preview='tmux capture-pane -t {1}:! -p 2>/dev/null | head -20' \
        --preview-window=right:50% \
  | awk '{print $1}')

[ -n "$chosen" ] && tmux switch-client -t "$chosen"
