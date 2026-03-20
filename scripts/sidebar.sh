#!/usr/bin/env bash
# tmux-ws sidebar — renders workspace/pane list with Claude status.
# Runs in a tmux pane. Receives refresh signals via FIFO.
#
# Usage: sidebar.sh <session_name>
#
# State machine per pane:
#   Running (✦)            — Claude is working
#   Done + unread (●)      — Claude finished, user hasn't looked
#   Done + read            — User focused the pane, just show message
#   Attention + unread (⚠) — Claude needs permission
#   Attention + read       — User focused, just show message

SESSION_NAME="${1:-$(tmux display-message -p '#S' 2>/dev/null)}"

# ── Mouse tracking ──
printf '\e[?1000h\e[?1006h'

# ── FIFO setup ──
FIFO_DIR="/tmp/tmux-ws"
mkdir -p "$FIFO_DIR/status"
FIFO="$FIFO_DIR/fifo-$SESSION_NAME"
mkfifo "$FIFO" 2>/dev/null
exec 3<>"$FIFO"  # open read/write to avoid blocking

# ── Background FIFO watcher ──
# Reads FIFO, sends SIGUSR1 to us for instant wakeup.
# This lets the main loop sleep with `read -t 2` instead of polling at 50ms.
(while read _ <&3 2>/dev/null; do
  kill -USR1 $$ 2>/dev/null
done) &
FIFO_PID=$!

# ── Cleanup ──
cleanup() {
  printf '\e[?1000l\e[?1006l'
  kill "$FIFO_PID" 2>/dev/null
  exec 3>&-
  rm -f "$FIFO" "/tmp/tmux-sidebar-map.$$"
}
trap cleanup EXIT
trap 'LAST_OUTPUT=""' USR1

MAPFILE="/tmp/tmux-sidebar-map.$$"
CURRENT_SESSION=""
LAST_OUTPUT=""
STATUS_DIR="$FIFO_DIR/status"

# ── Status reader ──
get_claude_status() {
  local file="$STATUS_DIR/$1"
  [ -f "$file" ] || return
  local state="" message="" ts="" unread=""
  while IFS='=' read -r key val; do
    case "$key" in
      state) state="$val" ;;
      message) message="$val" ;;
      ts) ts="$val" ;;
      unread) unread="$val" ;;
    esac
  done < "$file"
  if [ -n "$ts" ]; then
    local now; now=$(date +%s)
    [ $((now - ts)) -gt 600 ] && return
  fi
  echo "$state|$unread|$message"
}

mark_read() {
  local file="$STATUS_DIR/$1"
  [ -f "$file" ] && sed -i 's/^unread=true$/unread=false/' "$file"
}

# ── Render ──
render() {
  CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null) || exit 0
  local cols rows line output
  cols=$(tput cols 2>/dev/null || echo 24)
  rows=$(tput lines 2>/dev/null || echo 40)

  : > "$MAPFILE"
  line=1
  output=""

  output+="\033[1;36m WORKSPACES\033[0m"$'\n'
  ((line++))
  output+="$(printf '%.0s─' $(seq 1 $((cols - 1))))"$'\n'
  ((line++))

  while IFS='|' read -r sname swins attached; do
    printf '%s|session|%s\n' "$line" "$sname" >> "$MAPFILE"
    if [ "$sname" = "$CURRENT_SESSION" ]; then
      output+="\033[1;33m▶ $sname\033[0m"$'\n'
    else
      output+="\033[0;37m  $sname\033[0m"$'\n'
    fi
    ((line++))

    while IFS='|' read -r widx wname wactive wpanes; do
      # Include @tmux-ws-role to identify sidebar panes
      while IFS='|' read -r pidx pcmd pactive pane_id prole; do
        # Skip sidebar panes
        [ "$prole" = "sidebar" ] && continue

        printf '%s|pane|%s:%s.%s\n' "$line" "$sname" "$widx" "$pidx" >> "$MAPFILE"

        local status_id="${pane_id#%}"
        local claude_info
        claude_info=$(get_claude_status "$status_id")

        local is_focused=false
        [ "$pactive" = "1" ] && [ "$wactive" = "1" ] && [ "$sname" = "$CURRENT_SESSION" ] && is_focused=true

        local label maxlen
        maxlen=$((cols - 6))

        if [ -n "$claude_info" ]; then
          local cstate="${claude_info%%|*}"
          local rest="${claude_info#*|}"
          local cunread="${rest%%|*}"
          local cmsg="${rest#*|}"

          $is_focused && [ "$cunread" = "true" ] && mark_read "$status_id" && cunread="false"

          case "$cstate" in
            Running)
              label="✦ ${cmsg:-Working...}"
              [ ${#label} -gt $maxlen ] && label="${label:0:$maxlen}.."
              output+="  \033[1;33m$label\033[0m"$'\n'
              ;;
            Done)
              if [ "$cunread" = "true" ]; then
                label="● ${cmsg:-Done}"
                [ ${#label} -gt $maxlen ] && label="${label:0:$maxlen}.."
                output+="  \033[1;34m$label\033[0m"$'\n'
              else
                label="${cmsg:-Done}"
                [ ${#label} -gt $maxlen ] && label="${label:0:$maxlen}.."
                output+="  \033[2m  $label\033[0m"$'\n'
              fi
              ;;
            Attention)
              if [ "$cunread" = "true" ]; then
                label="⚠ ${cmsg:-Needs input}"
                [ ${#label} -gt $maxlen ] && label="${label:0:$maxlen}.."
                output+="  \033[1;31m$label\033[0m"$'\n'
              else
                label="${cmsg:-Needs input}"
                [ ${#label} -gt $maxlen ] && label="${label:0:$maxlen}.."
                output+="  \033[2m  $label\033[0m"$'\n'
              fi
              ;;
            *)
              label="$pcmd"
              [ ${#label} -gt $maxlen ] && label="${label:0:$maxlen}.."
              if $is_focused; then
                output+="  \033[32m● $label\033[0m"$'\n'
              else
                output+="  \033[2m○ $label\033[0m"$'\n'
              fi
              ;;
          esac
        else
          label="$pcmd"
          [ ${#label} -gt $maxlen ] && label="${label:0:$maxlen}.."
          if $is_focused; then
            output+="  \033[32m● $label\033[0m"$'\n'
          else
            output+="  \033[2m○ $label\033[0m"$'\n'
          fi
        fi
        ((line++))
      done < <(tmux list-panes -t "${sname}:${widx}" -F '#{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_id}|#{@tmux-ws-role}' 2>/dev/null)
    done < <(tmux list-windows -t "$sname" -F '#{window_index}|#{window_name}|#{window_active}|#{window_panes}' 2>/dev/null)

    output+=$'\n'
    ((line++))
  done < <(tmux list-sessions -F '#{session_name}|#{session_windows}|#{session_attached}' 2>/dev/null)

  local footer=""
  footer+="$(printf '%.0s─' $(seq 1 $((cols - 1))))"$'\n'
  footer+="\033[2m click = switch\033[0m"$'\n'
  footer+="\033[2m ^b w = hide\033[0m"

  if [ "$output" != "$LAST_OUTPUT" ]; then
    LAST_OUTPUT="$output"
    tput home 2>/dev/null
    tput ed 2>/dev/null
    printf "%b" "$output"
    tput cup $((rows - 3)) 0 2>/dev/null
    printf "%b" "$footer"
  fi
}

# ── Click handler ──
handle_click() {
  local y="$1"
  local match
  match=$(awk -F'|' -v line="$y" '$1 == line { print $2 "|" $3; exit }' "$MAPFILE")
  [ -z "$match" ] && return

  local type="${match%%|*}"
  local value="${match#*|}"

  if [ "$type" = "session" ]; then
    tmux switch-client -t "$value" 2>/dev/null
  elif [ "$type" = "pane" ]; then
    local sess="${value%%:*}"
    local rest="${value#*:}"
    local win="${rest%%.*}"
    local pane="${rest#*.}"
    [ "$sess" != "$CURRENT_SESSION" ] && tmux switch-client -t "$sess" 2>/dev/null
    tmux select-window -t "${sess}:${win}" 2>/dev/null
    tmux select-pane -t "${sess}:${win}.${pane}" 2>/dev/null
  fi
}

parse_and_handle_mouse() {
  local seq="" c
  while IFS= read -rsn1 -t 0.1 c; do
    seq+="$c"
    [[ "$c" == "M" || "$c" == "m" ]] && break
  done
  local event="${seq: -1}"
  local data="${seq%[Mm]}"
  local button="${data%%;*}"
  if [[ "$button" == "0" && "$event" == "M" ]]; then
    local y="${data##*;}"
    handle_click "$y"
  fi
}

# ── Main loop ──
# Sleeps up to 2 seconds. Wakes instantly on:
#   - Mouse click (stdin data)
#   - FIFO event (background watcher sends SIGUSR1)
render

while true; do
  if IFS= read -rsn1 -t 2 char; then
    if [[ "$char" == $'\e' ]]; then
      IFS= read -rsn1 -t 0.1 c2
      if [[ "$c2" == "[" ]]; then
        IFS= read -rsn1 -t 0.1 c3
        if [[ "$c3" == "<" ]]; then
          parse_and_handle_mouse
          LAST_OUTPUT=""
        fi
      fi
    fi
  fi
  render
done
