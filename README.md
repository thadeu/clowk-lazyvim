# Neovim config (LazyVim) + Ghostty

A terminal-first setup that keeps VSCode's `cmd+` shortcuts working inside
Neovim. Built for macOS with [Ghostty](https://ghostty.org) as the terminal.

Language stacks wired up: TypeScript (React/Vite, Node/Express, Prisma,
Tailwind) and Ruby on Rails, plus Docker, YAML and JSON.

![Neovim with this config: file explorer on the left, three buffer tabs, and two
vertical splits each carrying its own breadcrumb in the winbar](images/lazyvim.png)

The breadcrumb at the top of each split (`lua › config › keymaps.lua`) is
`dropbar.nvim`, and it is per window — both sides of a split get their own. The
colours are `clowk-night`, matching the Ghostty theme in `setup/ghostty/`.

## Install

```sh
git clone https://github.com/thadeu/clowk-lazyvim.git ~/code/clowk-lazyvim
~/code/clowk-lazyvim/setup/install.sh
```

That is the whole thing. The script is idempotent — re-run it any time — and it:

1. installs the Homebrew dependencies that are missing, and only those
2. refuses to continue on Neovim < 0.11, and warns when `node` or `gem` is
   absent, since mason needs them and says so in neither case
3. symlinks `~/.config/nvim` to the clone, moving an existing config (plus its
   plugin and mason state) to `~/.config/nvim-backup-<timestamp>`
4. installs the plugins at the commits in `lazy-lock.json`
5. installs the language servers and **waits** for them (see `setup/mason.lua`)
6. installs the Ghostty config, merging into an existing one instead of
   clobbering it, and validates the result

`--minimal` skips the optional tools. The only manual step left is
`gh auth login`, which is interactive.

Verify a server actually attached by opening a file and pressing `<leader>cl`.

## Dependencies

The script installs all of these; the list is here so you know what each one
buys you.

Required:

```sh
brew install neovim ripgrep fd
brew install --cask ghostty font-jetbrains-mono-nerd-font
```

- **neovim** 0.11+ — `dropbar.nvim` (the breadcrumb) requires it, and the
  bundled `nvim-treesitter` is the `main` branch. Developed on 0.12.
- **ripgrep** and **fd** — the LazyVim picker uses them for grep and file
  search. Without them `<leader><space>` and `<leader>/` are slow or empty.
- **ghostty** — the `cmd+` shortcuts depend on its `esc:` keybind action.
  Everything else works in any terminal.
- **font-jetbrains-mono-nerd-font** — the *Nerd Font* build, not
  `font-jetbrains-mono`. LazyVim's file icons, git signs and diagnostics are all
  Nerd Font glyphs, and the plain family renders every one of them as a tofu
  box. Any other Nerd Font works too; set it in the Ghostty config.

Optional, each unlocking one feature:

```sh
brew install lazygit gh
brew install mermaid-cli imagemagick
```

- **lazygit** — `<leader>gg`. Commit graph, interactive rebase, stage-by-hunk.
- **gh** — the PR/issue pickers and `octo.nvim`. Needs `gh auth login`.
- **mermaid-cli** (`mmdc`) — renders Mermaid diagrams inline in markdown buffers.
- **imagemagick** (`magick`) — inline images for svg, pdf and raster formats.
  Not needed for Mermaid.

Note that `brew install mermaid-cli` pulls Homebrew's `node` as a dependency. If
you manage Node with fnm/asdf/mise, make sure your version manager still comes
first on `PATH`.

Language servers are installed by [mason](https://github.com/mason-org/mason.nvim)
on demand, but two of them need a runtime on your host:

- **Node 20+** for `vtsls` (TypeScript). Any version manager works.
- **A working Ruby** for `ruby-lsp` and `rubocop` — both are gems, so without
  `ruby`/`gem` on PATH mason fails to install them, and the error message does
  not mention Ruby at all.

## Installing by hand

The same steps without the script. The order matters: mason cannot install
anything before lazy has cloned it.

```sh
git clone https://github.com/thadeu/clowk-lazyvim.git ~/code/clowk-lazyvim
ln -s ~/code/clowk-lazyvim ~/.config/nvim

nvim --headless "+Lazy! restore" +qa
nvim --headless -c "luafile $HOME/.config/nvim/setup/mason.lua"
```

Then the Ghostty config, which is what makes the `cmd+` shortcuts reach the
editor. **On macOS the file that wins is the one under Application Support**,
not `~/.config/ghostty` — see the notes at the bottom:

```sh
GHOSTTY="$HOME/Library/Application Support/com.mitchellh.ghostty"

mkdir -p "$GHOSTTY/themes"
cp ~/.config/nvim/setup/ghostty/themes/clowk-night "$GHOSTTY/themes/"
cp ~/.config/nvim/setup/ghostty/config "$GHOSTTY/config"
```

That last line replaces any Ghostty config you already have. To keep yours,
append only the block between the `clowk-lazyvim keybinds` markers of
`setup/ghostty/config` — which is what `setup/install.sh` does.

Restart Ghostty, or press `cmd+shift+,` to reload its config.

Do **not** reach for `nvim --headless "+MasonInstall ..." +qa`, the obvious
command: it fails twice over, and `setup/mason.lua` exists to work around both.
See the notes at the bottom.

## Shortcuts

### VSCode's `cmd+` keys

Ghostty rewrites `cmd+X` into `ESC+X` through its `esc:` action, and Neovim
receives that as `<M-X>`. See `setup/ghostty/config`.

| Key | Action |
| --- | --- |
| `cmd+j` | toggle terminal |
| `cmd+w` | close buffer (keeps the window layout) |
| `cmd+n` | new buffer |
| `cmd+\|` | vertical split |
| `cmd+1..5` | go to tab N (bufferline) |
| `cmd+shift+w` / `cmd+shift+n` | Ghostty's own close/new, moved aside |
| `option+double-click` | definition of the symbol in a vertical split |

### LSP (LazyVim defaults)

| Key | Action |
| --- | --- |
| `gd` / `gr` / `gI` / `gy` | definition / references / implementation / type |
| `K` / `gK` | hover / signature help |
| `<leader>ca` / `<leader>cr` | code action / rename |
| `<leader>cf` | format |
| `<leader>cl` | Lsp Info — check whether a server attached |
| `<C-o>` / `<C-i>` | jump list back / forward |

### Git

Most of this ships with LazyVim already; discoverability is the hard part, so
it is all listed here. Requires `gh` for the PR and issue entries.

GitHub Enterprise works out of the box: octo derives the host from the repo's
git remote, so a self-hosted instance needs no extra configuration.

| Key | Action | Source |
| --- | --- | --- |
| (automatic) | inline blame at end of line | gitsigns, enabled in `lua/plugins/git.lua` |
| `<leader>uB` | toggle inline blame | `lua/config/keymaps.lua` |
| `<leader>ghb` / `<leader>ghB` | blame line (full) / blame buffer | LazyVim |
| `<leader>gb` | line history | LazyVim |
| `<leader>gf` | current file history | LazyVim |
| `<leader>gl` / `<leader>gL` | git log for repo / cwd | LazyVim |
| `<leader>gd` / `<leader>gD` | diff by hunks / against origin | LazyVim |
| `<leader>gs` / `<leader>gS` | git status / stash | LazyVim |
| `<leader>gg` | lazygit | LazyVim |
| `<leader>gB` | open current line on GitHub | LazyVim |
| `<leader>ghs` / `<leader>ghr` / `<leader>ghp` | stage / reset / preview hunk | LazyVim |
| `]h` / `[h` | next / previous hunk | LazyVim |
| `<leader>gp` / `<leader>gP` | list / search PRs (Octo) | `util.octo` extra |
| `<leader>gi` / `<leader>gI` | list / search issues (Octo) | `util.octo` extra |
| `<leader>gvd` | diffview of the working tree | `lua/plugins/git.lua` |
| `<leader>gvb` | diffview of your changes vs base branch | `lua/plugins/git.lua` |
| `<leader>gvf` / `<leader>gvF` | file / branch history (diffview) | `lua/plugins/git.lua` |
| `<leader>gvc` or `q` | close diffview | `lua/plugins/git.lua` |

### Other

| Key | Action |
| --- | --- |
| `<leader>H` / `<leader>h` / `<leader>1..9` | harpoon: anchor / menu / jump |
| `<leader>cb` | breadcrumb: pick a segment (or click one) |
| `<leader>uw` | toggle wrap |
| `<leader>uf` | toggle format-on-save |
| `zs` / `ze` / `zH` / `zL` | manual horizontal scrolling |

## Breadcrumb

LazyVim ships no breadcrumb. What it enables by default is the trouble symbol
path in the **statusline at the bottom** — the symbol you are inside, without
the file path. The `editor.navic` extra does not help either: it also writes to
the statusline, and only when `vim.g.trouble_lualine` is false, which is not the
default.

`lua/plugins/breadcrumb.lua` adds `dropbar.nvim`, which puts the VSCode-style
path in the **winbar**, one line per window:

```
 lua  plugins  markdown.lua  return  [1]  opts  image  doc
```

It builds the path from LSP `documentSymbol`, treesitter and the file path, in
that order. Every segment is clickable and opens a menu to jump; `<leader>cb`
does the same from the keyboard.

The symbol part is therefore duplicated between the winbar and the statusline.
To keep it only at the top, set `vim.g.trouble_lualine = false` in
`lua/config/options.lua`.

Note that the buffer tabs cannot be made taller: every bufferline plugin writes
to `vim.o.tabline`, which is exactly one screen line.

## Markdown and Mermaid

Three layers, each for a different need:

| What | How | Needs |
| --- | --- | --- |
| Pretty buffer (headings, tables, code blocks) | `render-markdown.nvim` | — |
| **Mermaid diagrams inline in the buffer** | `snacks.image` + Kitty graphics protocol | `mmdc` |
| Full-fidelity live preview in a browser | `:MarkdownPreviewToggle` | — |

The inline path is the terminal-native one: no browser, the diagram renders in
place under the fenced block. It works because Ghostty implements the Kitty
graphics protocol — snacks supports `kitty`, `wezterm` and `ghostty`. In a
terminal without that protocol, snacks falls back to a floating window.

`snacks.image` is opt-in upstream, so `lua/plugins/markdown.lua` enables it and
raises the diagram size limits (the 80x40 default makes most flowcharts
unreadable). LaTeX math renders the same way.

Run `:checkhealth snacks` to see which external tools were detected.

## Machine-local overrides

The tracked config stays generic. Anything specific to one machine or one set of
projects goes in files that git ignores:

| File | Purpose |
| --- | --- |
| `lua/config/local.lua` | variables, loaded from `options.lua` via `pcall` |
| `lua/plugins/local-*.lua` | extra plugin specs, auto-imported by lazy |

Both are optional — the config works with neither present. `lua/plugins/` is
imported as a whole directory, so any `local-*.lua` you drop there is picked up
without registering it anywhere.

Example, for a project whose gems only exist inside a container and whose
rubocop therefore has to run through `docker compose exec`: put that formatter in
`lua/plugins/local-ruby-docker.lua` and its service name in
`lua/config/local.lua`. Neither leaves your machine.

## Notes from building this

Each of these cost a debugging session. They are also commented in the config
files, next to the code that works around them.

**Ghostty does not support end-of-line comments, and fails silently.**
`keybind = super+j=esc:j   # comment` passes `ghostty +validate-config` with exit
0, because the `esc:` action accepts arbitrary text — and it then sends the whole
comment along with the key. Named actions like `close_surface` raise
`InvalidAction`, which is what exposes the problem. Keep comments on their own
line.

**On macOS, `~/.config/ghostty/config` loses to Application Support.**
Ghostty reads `~/Library/Application Support/com.mitchellh.ghostty/config` after
the XDG path, so the App Support file wins. Measured: with `font-size = 99` in
`~/.config/ghostty/config` and `14` in App Support, `ghostty +show-config`
answers `14`. Every guide tells you to install into `~/.config/ghostty`, and on
any machine that has already opened Ghostty's own config editor that is a no-op
you can stare at for a while.

**`cmd+1..5` needs the physical key bound as well.**
Ghostty ships defaults on the physical key (`super+digit_1=goto_tab:1`) that
coexist with the unicode trigger (`super+1`) in `ghostty +show-config`. Binding
only `super+one` leaves `cmd+1` able to switch the Ghostty tab instead of
reaching Neovim, so `setup/ghostty/config` binds both.

**`nvim --headless "+MasonInstall ..." +qa` does not work, in two ways.**
First, `:MasonInstall` does not exist there — mason is lazy-loaded and the
command only appears once the plugin loads, so nvim answers `E492: Not an editor
command`. Second, even where the command does exist, `+qa` quits as soon as the
jobs are spawned: mason prints "Neovim is exiting while packages are still
installing" and leaves a half-populated directory that looks fine until a server
silently fails to attach. `setup/mason.lua` drives the registry API instead and
blocks on `pkg:is_installed()`.

**nvim-treesitter `main` needs the `tree-sitter` CLI.**
Without it no parser installs, and the only symptom is a health-check line
(`❌ tree-sitter (CLI)`) you have to go looking for. It is in the
`setup/mason.lua` list.

**A key mapping has to exist in insert mode too.**
If `<M-w>` only exists in normal mode, the `ESC+w` Ghostty sends matches nothing:
the `ESC` leaves insert mode and `w` runs as a word motion. The `map_ni` helper
in `lua/config/keymaps.lua` registers both.

**"Loose canvas" horizontal scrolling comes from the trackpad, not from config.**
macOS trackpads emit horizontal scroll events from any sideways drift of the
finger. With `wrap = false` Neovim shifts the window sideways and it stays there;
lines shorter than the offset render empty and the file looks like scattered
fragments. Measured: 12 events moved `leftcol` from 0 to 72. The
`<ScrollWheelLeft/Right>` mappings are disabled.

**LazyVim's `sidescrolloff = 8` causes premature horizontal scrolling.**
It demands 8 columns of slack between cursor and edge, so the window starts
scrolling before the text reaches it. Set to 0 in `lua/config/options.lua`.

**Harpoon is not a replacement for tabs.**
Its list starts empty, so `cmd+1` with nothing anchored does nothing — which
reads as a bug. `cmd+1..5` uses bufferline (position = the tab you see). Harpoon
lives on `<leader>1..9`, for anchors that do not shift position.

**Diffview opens in a tab page, not a float.**
So `<Esc>` closes nothing, and it ships no close mapping in the view or file
panel (only in the option and help panels). `q` was added to the **panels**; in
the view itself the diff buffers are editable and `q` has to stay macro
recording, so use `<leader>gvc`.

**LazyVim's octo extra points at telescope, which is not installed here.**
The extra sets `picker = "telescope"`; this config uses the snacks picker. The
override in `lua/plugins/octo.lua` switches it to `"snacks"` — verified against
octo's source, which resolves `octo.pickers.<picker>.provider`.

**A "missing" shortcut is sometimes just not registered yet.**
The gitsigns ones (`<leader>gh*`, `]h`, `[h`) are buffer-local, created in
`on_attach` — outside a git repository they do not exist. The LSP ones (`gd`,
`gr`, `K`, `<leader>cl`) are created on `LspAttach`; with no server attached they
do not exist, and `gd` silently falls back to Vim's built-in behaviour. That is
what makes `gd` look broken in a language whose server was never installed.

## Layout

```
init.lua                      entry point; loads lua/config/lazy.lua
lazy-lock.json                exact plugin commits
colors/clowk-night.lua        colorscheme matching the Ghostty theme
lua/config/
  lazy.lua                    extras: typescript, tailwind, prisma, json,
                              ruby, docker, yaml, markdown, harpoon2, octo
  keymaps.lua                 cmd+ shortcuts, horizontal scroll off, blame toggle
  options.lua                 sidescrolloff / sidescroll, ruby lsp choice
  autocmds.lua                (empty -- kept for your own autocmds)
lua/plugins/
  git.lua                     inline blame, diffview
  octo.lua                    picker -> snacks
  markdown.lua                snacks.image for inline mermaid / math
  harpoon.lua                 note on harpoon vs bufferline
  breadcrumb.lua              dropbar: VSCode-style path in the winbar
  colorscheme.lua
setup/
  install.sh                  one-shot installer, idempotent
  mason.lua                   installs the language servers and waits for them
  ghostty/                    terminal config: cmd+ keybinds, theme, typography
```

## Out of scope

Shell (`.zshrc`) and git (`.gitconfig`) configuration are intentionally not part
of this repo — it is an editor config, not a full dotfiles setup.

Also not included: a debugger setup. `nvim-dap` is noticeably weaker than
VSCode's debugger for Node and React; keeping VSCode around just for debugging
sessions, or using `node --inspect` with Chrome DevTools, is the pragmatic call.

## Credits

- [LazyVim](https://github.com/LazyVim/LazyVim) and its starter template, which
  this config is built on.
- `colors/clowk-night.lua` was produced by a third-party generator
  (`clowk-terminal`) rather than written here; check its upstream terms before
  reusing that file.
