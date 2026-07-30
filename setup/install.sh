#!/usr/bin/env bash
#
# One-shot installer for this config on a fresh macOS.
#
#   ./setup/install.sh              everything, including the optional tools
#   ./setup/install.sh --minimal    skip lazygit / gh / mermaid-cli / imagemagick
#
# Safe to re-run: every step checks its own result first, and anything it would
# overwrite is moved to ~/.config/nvim-backup-<timestamp> instead.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
BACKUP="$HOME/.config/nvim-backup-$(date +%Y%m%d-%H%M%S)"
MIN_NVIM="0.11.0"
MINIMAL=0

[[ "${1:-}" == "--minimal" ]] && MINIMAL=1

step() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$1"; }
info() { printf '    %s\n' "$1"; }
warn() { printf '\033[1;33m    warning:\033[0m %s\n' "$1"; }
die() {
  printf '\033[1;31m==> error:\033[0m %s\n' "$1" >&2
  exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || die "this installer is macOS only"
command -v brew >/dev/null || die "Homebrew not found -- https://brew.sh"

# --- Dependencies -------------------------------------------------------------

step "Installing dependencies"

# `brew install` on an already-installed formula is a no-op that still costs a
# few seconds each, so ask brew once what is missing.
installed_formulae="$(brew list --formula -1)"
installed_casks="$(brew list --cask -1)"

# macOS ships bash 3.2, so no `mapfile` and no associative arrays here.
need_req=()
need_opt=()
need_cask=()

for pkg in neovim ripgrep fd; do
  grep -qx "$pkg" <<<"$installed_formulae" || need_req+=("$pkg")
done

# lazygit -> <leader>gg, gh -> the PR/issue pickers and octo.nvim,
# mmdc -> inline Mermaid, magick -> inline svg/pdf/raster images.
if [[ $MINIMAL -eq 0 ]]; then
  for pkg in lazygit gh mermaid-cli imagemagick; do
    grep -qx "$pkg" <<<"$installed_formulae" || need_opt+=("$pkg")
  done
fi

for pkg in ghostty font-jetbrains-mono-nerd-font; do
  grep -qx "$pkg" <<<"$installed_casks" || need_cask+=("$pkg")
done

if [[ ${#need_req[@]} -gt 0 ]]; then
  info "brew install ${need_req[*]}"
  brew install "${need_req[@]}" || die "could not install ${need_req[*]}"
fi

# An optional tool that fails to build costs one feature, not the install.
if [[ ${#need_opt[@]} -gt 0 ]]; then
  info "brew install ${need_opt[*]}"
  brew install "${need_opt[@]}" || warn "some optional tools failed -- rerun brew by hand to see which"
fi

# Casks are never fatal: Ghostty may have come from the .dmg, and a font
# installed by hand (not by brew) makes the cask abort with "It seems there is
# already a Font at ...". `--adopt` takes ownership of those files instead; if
# that also fails, the only cost is the icons rendering as tofu boxes.
if [[ ${#need_cask[@]} -gt 0 ]]; then
  info "brew install --cask ${need_cask[*]}"
  brew install --cask "${need_cask[@]}" ||
    brew install --cask --adopt "${need_cask[@]}" ||
    warn "cask install failed -- install ${need_cask[*]} by hand if something looks wrong"
fi

if [[ ${#need_req[@]} -eq 0 && ${#need_opt[@]} -eq 0 && ${#need_cask[@]} -eq 0 ]]; then
  info "everything already present"
fi

# mermaid-cli depends on Homebrew's node. If you manage Node with fnm/asdf/mise,
# yours has to stay first on PATH or vtsls ends up on the wrong runtime.
if [[ $MINIMAL -eq 0 ]] && command -v node >/dev/null; then
  case "$(command -v node)" in
    /opt/homebrew/bin/node | /usr/local/bin/node)
      warn "node resolves to Homebrew's ($(command -v node)); a version manager would normally come first on PATH"
      ;;
  esac
fi

# --- Version gate -------------------------------------------------------------

step "Checking Neovim version"

nvim_version="$(nvim --version | head -1 | sed 's/^NVIM v//')"

# `sort -V` puts the lower version first; if that is not the minimum, we are below it.
if [[ "$(printf '%s\n%s\n' "$MIN_NVIM" "$nvim_version" | sort -V | head -1)" != "$MIN_NVIM" ]]; then
  die "Neovim $nvim_version is too old -- this config needs $MIN_NVIM+ (dropbar.nvim). Run: brew upgrade neovim"
fi

info "Neovim $nvim_version"

# Both are needed by mason, and its failure message names neither.
command -v node >/dev/null || warn "no node on PATH -- vtsls (TypeScript) will not install"
command -v gem >/dev/null || warn "no gem on PATH -- ruby-lsp, rubocop and erb-lint will not install"

# --- Link the config ----------------------------------------------------------

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

# --- Plugins ------------------------------------------------------------------

step "Installing plugins at the commits in lazy-lock.json"

nvim --headless "+Lazy! restore" +qa 2>&1 | tail -1
info "done"

# --- Language servers ---------------------------------------------------------

step "Installing language servers (mason)"

info "this takes a few minutes on a cold machine"
nvim --headless -c "luafile $REPO/setup/mason.lua" 2>&1 | grep -E '^mason:' || true

# --- Ghostty ------------------------------------------------------------------

step "Installing the Ghostty config"

mkdir -p "$GHOSTTY_DIR/themes"
cp "$REPO/setup/ghostty/themes/clowk-night" "$GHOSTTY_DIR/themes/clowk-night"

# On macOS Ghostty reads ~/Library/Application Support/com.mitchellh.ghostty/
# AFTER $XDG_CONFIG_HOME/ghostty, so the App Support file is the one that wins.
# Installing into ~/.config/ghostty is what most guides say and it is silently
# ignored on any machine that already has the App Support config.
if [[ -f "$HOME/.config/ghostty/config" ]]; then
  warn "~/.config/ghostty/config exists and is overridden by the App Support config below"
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

if ghostty +validate-config >/dev/null 2>&1; then
  info "ghostty +validate-config: ok"
else
  warn "ghostty +validate-config failed -- run it by hand to see why"
fi

# --- Done ---------------------------------------------------------------------

step "Done"

cat <<EOF

    Restart Ghostty (or press cmd+shift+, to reload it), then run: nvim

    Still manual, because it is interactive:
      gh auth login          enables the PR/issue pickers and octo.nvim

    Check that a server attached by opening a file and pressing <leader>cl.
EOF
