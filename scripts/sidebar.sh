#!/usr/bin/env bash
# Workspace sidebar with clickable sessions/panes.
# Click to switch workspace, tab, or pane.

printf '\e[?1000h\e[?1006h'
cleanup() {
  printf '\e[?1000l\e[?1006l'
  rm -f "/tmp/tmux-sidebar-map.$$"
}
trap cleanup EXIT

MAPFILE="/tmp/tmux-sidebar-map.$$"
CURRENT_SESSION=""
LAST_OUTPUT=""

render() {
  CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null) || exit 0
  local cols rows line output
  cols=$(tput cols 2>/dev/null || echo 30)
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
      local is_sidebar_window=false
      [ "$wactive" = "1" ] && [ "$sname" = "$CURRENT_SESSION" ] && is_sidebar_window=true

      # List each pane directly under the workspace
      while IFS='|' read -r pidx pcmd pactive ptty; do
        # Skip the sidebar pane itself
        if $is_sidebar_window; then
          local pane_start
          pane_start=$(tmux display-message -t "$ptty" -p '#{pane_start_command}' 2>/dev/null)
          if echo "$pane_start" | grep -q "sidebar.sh"; then
            continue
          fi
        fi

        printf '%s|pane|%s:%s.%s\n' "$line" "$sname" "$widx" "$pidx" >> "$MAPFILE"
        local label="$pcmd"
        [ ${#label} -gt $((cols - 6)) ] && label="${label:0:$((cols - 6))}.."

        if [ "$pactive" = "1" ] && [ "$wactive" = "1" ] && [ "$sname" = "$CURRENT_SESSION" ]; then
          output+="  \033[32m● $label\033[0m"$'\n'
        else
          output+="  \033[2m○ $label\033[0m"$'\n'
        fi
        ((line++))
      done < <(tmux list-panes -t "${sname}:${widx}" -F '#{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_tty}' 2>/dev/null)

    done < <(tmux list-windows -t "$sname" -F '#{window_index}|#{window_name}|#{window_active}|#{window_panes}' 2>/dev/null)

    output+=$'\n'
    ((line++))
  done < <(tmux list-sessions -F '#{session_name}|#{session_windows}|#{session_attached}' 2>/dev/null)

  # Footer
  local footer=""
  footer+="$(printf '%.0s─' $(seq 1 $((cols - 1))))"$'\n'
  footer+="\033[2m click = switch\033[0m"$'\n'
  footer+="\033[2m ^b w = hide\033[0m"

  # Only redraw if something changed (prevents flicker)
  if [ "$output" != "$LAST_OUTPUT" ]; then
    LAST_OUTPUT="$output"
    tput home 2>/dev/null
    tput ed 2>/dev/null
    printf "%b" "$output"
    tput cup $((rows - 3)) 0 2>/dev/null
    printf "%b" "$footer"
  fi
}

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
    if [ "$sess" != "$CURRENT_SESSION" ]; then
      tmux switch-client -t "$sess" 2>/dev/null
    fi
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

render

while true; do
  if IFS= read -rsn1 -t 2 char; then
    if [[ "$char" == $'\e' ]]; then
      IFS= read -rsn1 -t 0.1 c2
      if [[ "$c2" == "[" ]]; then
        IFS= read -rsn1 -t 0.1 c3
        if [[ "$c3" == "<" ]]; then
          parse_and_handle_mouse
          LAST_OUTPUT=""  # force redraw after click
        fi
      fi
    fi
  fi
  render
done
