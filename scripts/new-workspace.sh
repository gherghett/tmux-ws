#!/usr/bin/env bash
read -p "Workspace name: " name
[ -z "$name" ] && exit 0
tmux new-session -d -s "$name" 2>/dev/null || { echo "Session '$name' exists"; sleep 1; exit 1; }
tmux switch-client -t "$name"
