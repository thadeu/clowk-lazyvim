# >>> clowk-lazyvim >>>
# Everything setup/install.sh appends to ~/.zshrc. Keep the markers intact: a
# re-run replaces this block instead of stacking another copy.

# Open Neovim inside its own tmux session.
#
# This is what turns cmd+j into tmux's floating popup -- a real pty drawn over
# the pane -- instead of Neovim's terminal buffer, where a full-screen TUI like
# Claude Code redraws itself in the wrong place. The binding lives in
# ~/.tmux.conf (setup/tmux/tmux.conf) and can only fire when Neovim runs inside
# tmux, hence this wrapper.
#
# Only Neovim pays the tmux tax this way: plain shell tabs stay outside it, with
# Ghostty's own scrollback and image protocol untouched.
#
# The session is unnamed, so every `nvim` gets its own instead of mirroring an
# existing one, and it ends when Neovim exits. `-t 1` keeps $EDITOR-style
# invocations (git commit, crontab) on the real binary, and the `command -v`
# check falls back to plain Neovim -- and to its own float on cmd+j -- on a
# machine without tmux.
nvim() {
  if [[ -n "$TMUX" ]] || [[ ! -t 1 ]] || ! command -v tmux >/dev/null 2>&1; then
    command nvim "$@"
    return
  fi

  tmux new-session nvim "$@"
}
# <<< clowk-lazyvim <<<
