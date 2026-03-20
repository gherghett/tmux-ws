# tmux-ws

Experimental tmux workspace manager — my personal config. Trying to recreate [gherghett/cmux](https://github.com/gherghett/cmux) (itself a reaction to [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux)) using plain tmux + bash scripts.

## Install

```bash
git clone https://github.com/gherghett/tmux-ws.git ~/.tmux
ln -sf ~/.tmux/tmux.conf ~/.tmux.conf
ln -sf ~/.tmux/scripts/tmux-ws ~/.local/bin/tmux-ws
```

Add to your `~/.bashrc`:

```bash
# tmux-ws: claude wrapper for sidebar status hooks
[ -n "$TMUX" ] && export PATH="$HOME/.tmux/scripts:$PATH"
```

This makes the `claude` wrapper active inside tmux so Claude Code status appears in the sidebar. Outside tmux, nothing changes.

## Usage

```bash
tmux-ws              # launch (creates default workspaces on first run)
tmux kill-server     # kill everything
```

### Shortcuts

| Keys | Action |
|------|--------|
| `Ctrl+b N` | New workspace |
| `Ctrl+b X` | Kill workspace |
| `Ctrl+b n/p` | Next/prev workspace |
| `Ctrl+b w` | Toggle sidebar |
| `Ctrl+b t` | New tab |
| `Alt+1-9` | Switch tab |
| `Ctrl+b \|` | Split side by side |
| `Ctrl+b -` | Split top/bottom |
| `Ctrl+b d` | Detach |

Click sidebar items to switch. Drag pane borders to resize.

## Claude Code integration

When you run `claude` inside tmux-ws, the wrapper injects hooks that report status to the sidebar:

- **✦ Working...** — Claude is processing
- **● message** — Claude finished (unread)
- **⚠ Needs input** — Claude needs permission

Status clears to "read" when you focus the pane.

## Extending

Drop executable scripts in `~/.tmux/hooks.d/` to react to Claude events. Each receives `$1=event` (active/stop/notification), `$2=pane_id`, `$3=status_file`.

Ships with:
- `01-refresh-sidebar` — signals sidebar to re-render
- `02-desktop-notify` — `notify-send` on stop/attention
