#!/usr/bin/env bash
# Signal the current session's sidebar to refresh via FIFO.
# Called by tmux hooks (pane-focus-in, client-session-changed).
SESSION=$(tmux display-message -p '#S' 2>/dev/null)
[ -n "$SESSION" ] && echo refresh > "/tmp/tmux-ws/fifo-$SESSION" 2>/dev/null &
exit 0
