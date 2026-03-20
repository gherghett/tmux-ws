#!/usr/bin/env bash
# Claude Code hook handler for tmux-ws.
# Called by Claude Code hooks (UserPromptSubmit, Stop, Notification).
# Writes pane status, then dispatches to ~/.tmux/hooks.d/ scripts.

SUBCOMMAND="$1"
PANE_ID="${TMUX_PANE#%}"

# Not in tmux — nothing to do
[ -z "$PANE_ID" ] && exit 0

STATUS_DIR="/tmp/tmux-ws/status"
mkdir -p "$STATUS_DIR"
STATUS_FILE="$STATUS_DIR/$PANE_ID"

# Read JSON from stdin
STDIN_DATA=$(cat)

# Simple JSON field extractor — no jq dependency
extract_field() {
  printf '%s' "$STDIN_DATA" | grep -oP "\"$1\"\s*:\s*\"\\K[^\"]*" | head -1
}

case "$SUBCOMMAND" in
  active)
    printf 'state=Running\nunread=false\nmessage=Working...\nts=%s\n' \
      "$(date +%s)" > "$STATUS_FILE"
    ;;
  stop)
    MSG=$(extract_field "last_assistant_message")
    printf 'state=Done\nunread=true\nmessage=%s\nts=%s\n' \
      "${MSG:0:100}" "$(date +%s)" > "$STATUS_FILE"
    ;;
  notification)
    MSG=$(extract_field "message")
    printf 'state=Attention\nunread=true\nmessage=%s\nts=%s\n' \
      "${MSG:0:100}" "$(date +%s)" > "$STATUS_FILE"
    ;;
  *) exit 0 ;;
esac

# Dispatch to all registered hooks in hooks.d/
HOOKS_DIR="$HOME/.tmux/hooks.d"
if [ -d "$HOOKS_DIR" ]; then
  for hook in "$HOOKS_DIR"/*; do
    [ -x "$hook" ] && "$hook" "$SUBCOMMAND" "$PANE_ID" "$STATUS_FILE" &
  done
fi
