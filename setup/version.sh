#!/usr/bin/env bash
#
# Version control for this config, on top of git tags.
#
#   ./setup/version.sh                 what is installed right now
#   ./setup/version.sh list            every released version, newest first
#   ./setup/version.sh release v0.2.0  tag the current commit and push it
#   ./setup/version.sh use v0.1.0      roll the whole setup back to a version
#   ./setup/version.sh use main        come back to the tip of main
#
# A "version" here is the config AND the plugin set: the tag pins the Lua files
# and the lazy-lock.json committed alongside them, and `use` replays that lock
# so the plugins go back to the exact commits that version was tested with.
# Rolling back the files alone would leave newer plugins running against older
# config, which is the state that actually breaks.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"

cd "$REPO"

step() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$1"; }
info() { printf '    %s\n' "$1"; }
die() {
  printf '\033[1;31m    error:\033[0m %s\n' "$1" >&2
  exit 1
}

# The Ghostty keybinds live outside the repo, so a rollback has to re-graft the
# block from the checked-out revision. Same merge as setup/install.sh: it keeps
# the machine's own preferences and only replaces what is between the markers.
install_ghostty_keybinds() {
  [[ -f "$GHOSTTY_DIR/config" ]] || return 0
  local tmp kept
  tmp="$(mktemp)"
  kept="$(sed '/^# >>> clowk-lazyvim keybinds >>>$/,/^# <<< clowk-lazyvim keybinds <<<$/d' "$GHOSTTY_DIR/config")"
  {
    printf '%s\n\n' "$kept"
    sed -n '/^# >>> clowk-lazyvim keybinds >>>$/,/^# <<< clowk-lazyvim keybinds <<<$/p' "$REPO/setup/ghostty/config"
  } >"$tmp"
  mv "$tmp" "$GHOSTTY_DIR/config"
}

# The cmd+j popup lives in ~/.tmux.conf, outside the repo just like the Ghostty
# keybinds, so a rollback has to re-graft it as well. A version that predates
# setup/tmux/tmux.conf gets the block REMOVED rather than left behind: rolling
# back means the machine ends up in the state that version was tested in.
install_tmux_block() {
  command -v tmux >/dev/null 2>&1 || return 0
  [[ -f "$HOME/.tmux.conf" || -f "$REPO/setup/tmux/tmux.conf" ]] || return 0

  local tmp kept
  tmp="$(mktemp)"
  kept=""

  if [[ -f "$HOME/.tmux.conf" ]]; then
    kept="$(sed '/^# >>> clowk-lazyvim >>>$/,/^# <<< clowk-lazyvim <<<$/d' "$HOME/.tmux.conf")"
  fi

  {
    if [[ -n "$kept" ]]; then
      printf '%s\n\n' "$kept"
    fi

    # The block only -- the top half of that file is personal preference, which
    # setup/install.sh writes just once, onto a machine with no config yet.
    if [[ -f "$REPO/setup/tmux/tmux.conf" ]]; then
      sed -n '/^# >>> clowk-lazyvim >>>$/,/^# <<< clowk-lazyvim <<<$/p' "$REPO/setup/tmux/tmux.conf"
    fi
  } >"$tmp"

  mv "$tmp" "$HOME/.tmux.conf"
}

cmd_status() {
  local tag ref dirty
  # --always so a commit with no tag still prints something usable.
  tag="$(git describe --tags --always 2>/dev/null || echo unknown)"
  ref="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$ref" == "HEAD" ]] && ref="detached"
  dirty=""
  git diff --quiet || dirty=" (uncommitted changes)"
  printf '    version  %s\n' "$tag$dirty"
  printf '    on       %s\n' "$ref"
  printf '    latest   %s\n' "$(git tag --sort=-v:refname | head -1 || echo none)"
}

cmd_list() {
  git tag --sort=-v:refname --format='    %(refname:short)  %(creatordate:short)  %(subject)'
}

cmd_release() {
  local tag="${1:-}"
  [[ -n "$tag" ]] || die "usage: version.sh release <tag>   e.g. v0.2.0"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "$tag already exists"
  git diff --quiet || die "uncommitted changes -- commit them first"

  step "Tagging $(git rev-parse --short HEAD) as $tag"
  git tag -a "$tag" -m "$tag"
  git push origin "$tag"
  info "pushed"
}

cmd_use() {
  local target="${1:-}"
  [[ -n "$target" ]] || die "usage: version.sh use <tag|main>"
  git rev-parse -q --verify "$target" >/dev/null 2>&1 ||
    git rev-parse -q --verify "origin/$target" >/dev/null 2>&1 ||
    die "no such version: $target (try: version.sh list)"
  git diff --quiet || die "uncommitted changes -- commit or stash them first"

  step "Switching the config to $target"
  # A tag checks out detached, which is correct: a version is a fixed point, and
  # committing on top of one by accident is worse than the detached-HEAD warning.
  git checkout --quiet "$target"
  info "$(git describe --tags --always)"

  step "Restoring the plugins pinned by this version"
  nvim --headless "+Lazy! restore" +qa 2>&1 | tail -1
  info "done"

  step "Re-applying the Ghostty keybinds of this version"
  install_ghostty_keybinds
  info "restart Ghostty, or press cmd+shift+, to reload it"

  step "Re-applying the tmux popup of this version"
  install_tmux_block
  info "tmux source-file ~/.tmux.conf to pick it up in a running session"

  cat <<EOF

    Back to the latest:  ./setup/version.sh use main
    Language servers are NOT rolled back -- mason keeps whatever is installed.
    If a version needs different ones: ./setup/install.sh
EOF
}

case "${1:-status}" in
status) cmd_status ;;
list) cmd_list ;;
release) cmd_release "${2:-}" ;;
use) cmd_use "${2:-}" ;;
*) die "unknown command: $1 (status | list | release <tag> | use <tag>)" ;;
esac
