#!/usr/bin/env bash
#
# One-shot installer for this config on macOS.
#
#   ./setup/install.sh              everything, including the optional tools
#   ./setup/install.sh --minimal    skip the optional tools
#
# It also runs straight from the web, with no clone of your own:
#
#   curl -fsSL https://raw.githubusercontent.com/thadeu/clowk-lazyvim/main/setup/install.sh | bash
#
# In that mode it clones the repo first (or pulls, if the clone is already
# there) and then re-runs itself from inside it -- see the bootstrap below.
# CLOWK_DIR overrides where that clone lands; the default is ~/code/clowk-lazyvim.
#
# Safe to re-run: every step checks its own result first, and anything it would
# overwrite is moved to ~/.config/nvim-backup-<timestamp> instead.
#
# Dependencies come in three tiers, and the script treats them differently:
#
#   CORE      Homebrew, neovim 0.11+, ripgrep, fd, tmux.
#             The config does not work without them, so a failure here aborts.
#             tmux is the one that degrades rather than breaks: it hosts the
#             cmd+j popup, and without it cmd+j falls back to Neovim's float.
#
#   STACK     node 20+ (TypeScript), ruby 3.2+ (Rails), a Nerd Font, Ghostty.
#             Each one gates a slice of the setup. A missing one SKIPS that
#             slice and is reported at the end -- it does not abort, because a
#             machine that never touches Rails does not need Ruby.
#
#   OPTIONAL  lazygit, gh, mermaid-cli, imagemagick.
#             One feature each. Failures are warnings.

set -euo pipefail

REPO_URL="https://github.com/thadeu/clowk-lazyvim.git"

# --- Bootstrap: the install always lives at one fixed path in $HOME ------------
#
# NOT wherever the script happens to be run from. Deriving the location from the
# script's own path gives a different install per copy of the repo, and piped
# from curl there is no script FILE at all: ${BASH_SOURCE[0]} is empty, and the
# usual `dirname .. ` trick silently resolves to the parent of whatever your cwd
# happens to be -- or to `/`. Everything below would then symlink ~/.config/nvim
# at that directory, AFTER moving the real config into a backup.
#
# One fixed path removes the whole question. ~/.config keeps the clone next to
# the config it becomes, and the symlink still points at it, so backups and
# setup/version.sh are unchanged.
REPO="${CLOWK_DIR:-$HOME/.config/clowk-lazyvim}"

self="${BASH_SOURCE[0]:-}"
self_repo=""
[[ -f "$self" ]] && self_repo="$(cd "$(dirname "$self")/.." && pwd)"

if [[ "$self_repo" != "$REPO" ]]; then
  # Running from a clone somewhere else -- a development checkout, say. Say so,
  # because the install is about to point at $REPO and not at the files being
  # read right now. CLOWK_DIR is the way to install from this one instead.
  if [[ -n "$self_repo" ]]; then
    printf '\n\033[1;33mnote:\033[0m running from %s, but installing to %s\n' "$self_repo" "$REPO"
    printf '      to install from this clone instead: CLOWK_DIR=%s %s\n' "$self_repo" "$self"
  fi

  command -v git >/dev/null 2>&1 ||
    { printf 'error: git is required to bootstrap. Install the Xcode command line tools: xcode-select --install\n' >&2; exit 1; }

  if [[ -d "$REPO/.git" ]]; then
    printf '\n\033[1;34m==>\033[0m \033[1mUpdating the existing clone at %s\033[0m\n' "$REPO"
    # --ff-only so local commits are reported as a conflict instead of being
    # merged into by a script running unattended.
    git -C "$REPO" pull --ff-only
  else
    printf '\n\033[1;34m==>\033[0m \033[1mCloning into %s\033[0m\n' "$REPO"
    mkdir -p "$(dirname "$REPO")"
    git clone "$REPO_URL" "$REPO"
  fi

  # Re-run from inside the clone, where every path below resolves. exec so this
  # process is replaced and the script body runs exactly once.
  exec bash "$REPO/setup/install.sh" "$@"
fi

GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
BACKUP="$HOME/.config/nvim-backup-$(date +%Y%m%d-%H%M%S)"

MIN_NVIM="0.11.0"
MIN_NODE="20.0.0"
MIN_RUBY="3.2.0"

MINIMAL=0
[[ "${1:-}" == "--minimal" ]] && MINIMAL=1

step() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$1"; }
info() { printf '    %s\n' "$1"; }
warn() { printf '\033[1;33m    skip:\033[0m %s\n' "$1"; }
die() {
  printf '\n\033[1;31m==> error:\033[0m %s\n' "$1" >&2
  exit 1
}

# graft_block <source> <target> -- put this repo's marked block into a config
# file the machine also owns, leaving everything else in it alone. Replacing the
# block instead of appending is what makes a re-run idempotent.
#
# The block always lands LAST, which ~/.tmux.conf depends on: tpm loads plugins
# where it is called, and a theme like dracula turns the status bar back on, so
# anything placed above it is silently undone.
graft_block() {
  local src="$1" dst="$2" tmp kept
  tmp="$(mktemp)"
  kept=""

  if [[ -f "$dst" ]]; then
    kept="$(sed '/^# >>> clowk-lazyvim >>>$/,/^# <<< clowk-lazyvim <<<$/d' "$dst")"
  fi

  {
    # `$(...)` drops every trailing newline, so the blank separator below is
    # written exactly once no matter how many times this runs.
    if [[ -n "$kept" ]]; then
      printf '%s\n\n' "$kept"
    fi

    cat "$src"
  } >"$tmp"

  mv "$tmp" "$dst"
}

# version_lt A B -- true when A is strictly older than B. macOS ships bash 3.2,
# so this is `sort -V` rather than anything fancier.
version_lt() {
  [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]
}

# What the run ends up supporting, reported in the summary.
STACK_TS="skipped"
STACK_RUBY="skipped"
STACK_GHOSTTY="skipped"
STACK_FONT="skipped"

# --- Core -------------------------------------------------------------------

step "Core requirements"

[[ "$(uname -s)" == "Darwin" ]] || die "this installer is macOS only"
command -v brew >/dev/null || die "Homebrew not found -- install it first: https://brew.sh"

installed_formulae="$(brew list --formula -1)"
installed_casks="$(brew list --cask -1)"

need_core=()

for pkg in neovim ripgrep fd tmux; do
  grep -qx "$pkg" <<<"$installed_formulae" || need_core+=("$pkg")
done

if [[ ${#need_core[@]} -gt 0 ]]; then
  info "brew install ${need_core[*]}"
  brew install "${need_core[@]}" || die "could not install ${need_core[*]}"
fi

# The version gate has to run after the install above, since that is what may
# have just provided nvim.
nvim_version="$(nvim --version | head -1 | sed 's/^NVIM v//')"

if version_lt "$nvim_version" "$MIN_NVIM"; then
  info "Neovim $nvim_version is below $MIN_NVIM (dropbar.nvim) -- upgrading"
  brew upgrade neovim || die "could not upgrade neovim -- it may not be the Homebrew build"
  nvim_version="$(nvim --version | head -1 | sed 's/^NVIM v//')"

  version_lt "$nvim_version" "$MIN_NVIM" && die "Neovim is still $nvim_version, need $MIN_NVIM+"
fi

info "neovim $nvim_version, ripgrep, fd, tmux"

# --- Stack runtimes ---------------------------------------------------------

step "Language stacks"

# Checking that the binary merely exists is not enough for either of these.
# macOS ships ruby 2.6.10 with a working `gem`, so a presence check passes on a
# machine where ruby-lsp (3.2+) cannot install at all.
node_version="$(node --version 2>/dev/null | sed 's/^v//' || true)"

if [[ -z "$node_version" ]]; then
  warn "TypeScript: no node on PATH -- vtsls, tailwind, prisma and json are skipped"
elif version_lt "$node_version" "$MIN_NODE"; then
  warn "TypeScript: node $node_version is below $MIN_NODE -- vtsls may misbehave"
  STACK_TS="node $node_version (below $MIN_NODE)"
else
  STACK_TS="node $node_version"
  info "TypeScript: node $node_version"
fi

ruby_version="$(ruby -e 'print RUBY_VERSION' 2>/dev/null || true)"

if [[ -z "$ruby_version" ]]; then
  warn "Rails: no ruby on PATH -- ruby-lsp, rubocop and erb-lint are skipped"
elif version_lt "$ruby_version" "$MIN_RUBY"; then
  warn "Rails: ruby $ruby_version is macOS's system ruby, ruby-lsp needs $MIN_RUBY+"
  warn "Rails: install a modern ruby with rbenv, mise or asdf, then re-run"
else
  STACK_RUBY="ruby $ruby_version"
  info "Rails: ruby $ruby_version"
fi

# Casks are never fatal. Ghostty may have come from the .dmg, and a font
# installed by hand (not by brew) makes the cask abort with "It seems there is
# already a Font at ..."; `--adopt` takes ownership of those files instead.
for cask in ghostty font-jetbrains-mono-nerd-font; do
  if grep -qx "$cask" <<<"$installed_casks"; then
    continue
  fi

  info "brew install --cask $cask"

  brew install --cask "$cask" >/dev/null 2>&1 ||
    brew install --cask --adopt "$cask" >/dev/null 2>&1 ||
    warn "$cask could not be installed by brew"
done

if command -v ghostty >/dev/null || [[ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]]; then
  STACK_GHOSTTY="present"
else
  warn "Ghostty not found -- the cmd+ shortcuts need it, everything else works anywhere"
fi

# The cask is one way to get a Nerd Font, a manual install is another, so look
# for the glyphs rather than for the cask.
if ls ~/Library/Fonts /Library/Fonts 2>/dev/null | grep -qi 'nerd'; then
  STACK_FONT="present"
else
  warn "no Nerd Font found -- LazyVim's icons will render as tofu boxes"
fi

# --- Optional ---------------------------------------------------------------

if [[ $MINIMAL -eq 0 ]]; then
  step "Optional tools"

  # lazygit -> <leader>gg, gh -> the PR/issue pickers and octo.nvim,
  # mmdc -> inline Mermaid, magick -> inline svg/pdf/raster images.
  need_opt=()

  for pkg in lazygit gh mermaid-cli imagemagick; do
    grep -qx "$pkg" <<<"$installed_formulae" || need_opt+=("$pkg")
  done

  if [[ ${#need_opt[@]} -gt 0 ]]; then
    info "brew install ${need_opt[*]}"
    brew install "${need_opt[@]}" || warn "some optional tools failed -- run brew by hand to see which"
  else
    info "already present"
  fi

  # mermaid-cli depends on Homebrew's node. If Node is managed by fnm/asdf/mise,
  # that one has to stay first on PATH or vtsls ends up on the wrong runtime.
  case "$(command -v node || true)" in
    /opt/homebrew/bin/node | /usr/local/bin/node)
      warn "node resolves to Homebrew's -- a version manager would normally come first on PATH"
      ;;
  esac
fi

# --- Config -----------------------------------------------------------------

step "Linking $REPO -> ~/.config/nvim"

if [[ "$(readlink ~/.config/nvim 2>/dev/null || true)" == "$REPO" ]]; then
  info "already linked"
elif [[ -e "$HOME/.config/nvim" || -L "$HOME/.config/nvim" ]]; then
  mkdir -p "$BACKUP"
  mv "$HOME/.config/nvim" "$BACKUP/config-nvim"
  # Plugin and mason state from another config survives the swap and produces
  # confusing half-broken sessions, so it moves out with it.
  [[ -d "$HOME/.local/share/nvim" ]] && mv "$HOME/.local/share/nvim" "$BACKUP/share-nvim"
  [[ -d "$HOME/.local/state/nvim" ]] && mv "$HOME/.local/state/nvim" "$BACKUP/state-nvim"
  ln -s "$REPO" "$HOME/.config/nvim"
  info "previous config moved to $BACKUP"
else
  mkdir -p "$HOME/.config"
  ln -s "$REPO" "$HOME/.config/nvim"
  info "linked"
fi

step "Installing plugins at the commits in lazy-lock.json"

nvim --headless "+Lazy! restore" +qa 2>&1 | tail -1
info "done"

step "Installing language servers (mason)"

info "this takes a few minutes on a cold machine"
# mason.lua gates the Ruby packages on a usable ruby itself, so a machine
# without one installs the rest and reports what it skipped.
# --line-buffered, or grep holds the progress lines in a 4K buffer and prints
# them all at the end -- which is exactly the silence the progress is there to
# break.
nvim --headless -c "luafile $REPO/setup/mason.lua" 2>&1 | grep --line-buffered -E '^mason:' || true

# --- Ghostty ----------------------------------------------------------------

step "Installing the Ghostty config"

mkdir -p "$GHOSTTY_DIR/themes"
cp "$REPO/setup/ghostty/themes/clowk-night" "$GHOSTTY_DIR/themes/clowk-night"

# On macOS Ghostty reads ~/Library/Application Support/com.mitchellh.ghostty/
# AFTER $XDG_CONFIG_HOME/ghostty, so the App Support file is the one that wins.
# Installing into ~/.config/ghostty is what most guides say and it is silently
# ignored on any machine that already has the App Support config.
if [[ -f "$HOME/.config/ghostty/config" ]]; then
  warn "~/.config/ghostty/config exists and is overridden by the App Support config"
fi

if [[ -f "$GHOSTTY_DIR/config" ]]; then
  # Keep the machine's own preferences (font, window size, ...) and graft only
  # the keybinds, replacing a previous block so re-runs do not stack copies.
  tmp="$(mktemp)"
  # `$(...)` drops every trailing newline, so the blank separator line below is
  # written exactly once no matter how many times this runs.
  kept="$(sed '/^# >>> clowk-lazyvim keybinds >>>$/,/^# <<< clowk-lazyvim keybinds <<<$/d' "$GHOSTTY_DIR/config")"
  {
    printf '%s\n\n' "$kept"
    sed -n '/^# >>> clowk-lazyvim keybinds >>>$/,/^# <<< clowk-lazyvim keybinds <<<$/p' "$REPO/setup/ghostty/config"
  } >"$tmp"
  mv "$tmp" "$GHOSTTY_DIR/config"
  info "merged the keybinds into your existing config, preferences untouched"
  info "the repo's font and theme were NOT applied -- see setup/ghostty/config"
else
  cp "$REPO/setup/ghostty/config" "$GHOSTTY_DIR/config"
  info "installed $GHOSTTY_DIR/config"
fi

# The cask installs the .app but puts no `ghostty` on PATH, so a fresh machine
# has to be pointed at the binary inside the bundle.
ghostty_bin="$(command -v ghostty || true)"

if [[ -z "$ghostty_bin" && -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]]; then
  ghostty_bin=/Applications/Ghostty.app/Contents/MacOS/ghostty
fi

if [[ -z "$ghostty_bin" ]]; then
  warn "ghostty binary not found -- config validation skipped"
elif "$ghostty_bin" +validate-config >/dev/null 2>&1; then
  info "ghostty +validate-config: ok"
else
  warn "ghostty +validate-config failed -- run it by hand to see why"
fi

# --- tmux and the shell -----------------------------------------------------

step "Installing the tmux popup and the Neovim wrapper"

if command -v tmux >/dev/null 2>&1; then
  graft_block "$REPO/setup/tmux/tmux.conf" "$HOME/.tmux.conf"
  info "merged the cmd+j popup into ~/.tmux.conf, your own settings untouched"

  if tmux source-file "$HOME/.tmux.conf" 2>/dev/null; then
    info "reloaded the running tmux server"
  fi
else
  warn "tmux not found -- cmd+j falls back to Neovim's own float"
fi

# The wrapper is what puts Neovim inside tmux in the first place, so the popup
# has a tmux to be drawn by. Nothing else in the config depends on the shell.
case "$SHELL" in
*/zsh)
  graft_block "$REPO/setup/zsh/nvim-tmux.zsh" "$HOME/.zshrc"
  info "merged the nvim wrapper into ~/.zshrc -- open a new tab to pick it up"
  ;;
*)
  warn "\$SHELL is $SHELL, not zsh -- port setup/zsh/nvim-tmux.zsh by hand"
  ;;
esac

# --- Summary ----------------------------------------------------------------

step "Summary"

printf '    %-12s %s\n' "core" "neovim $nvim_version, ripgrep, fd, tmux"
printf '    %-12s %s\n' "typescript" "$STACK_TS"
printf '    %-12s %s\n' "rails" "$STACK_RUBY"
printf '    %-12s %s\n' "ghostty" "$STACK_GHOSTTY"
printf '    %-12s %s\n' "nerd font" "$STACK_FONT"

cat <<EOF

    Anything reading "skipped" above is a stack you can enable later: install
    what it named and re-run this script.

    Restart Ghostty (or press cmd+shift+, to reload it), then run: nvim

    Still manual, because it is interactive:
      gh auth login          enables the PR/issue pickers and octo.nvim

    Check that a server attached by opening a file and pressing <leader>cl.
EOF
