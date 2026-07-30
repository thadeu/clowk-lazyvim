# Neovim config (LazyVim) + Ghostty

A terminal-first setup that keeps VSCode's `cmd+` shortcuts working inside
Neovim. Built for macOS with [Ghostty](https://ghostty.org) as the terminal.

Language stacks wired up: TypeScript (React/Vite, Node/Express, Prisma,
Tailwind) and Ruby on Rails, plus Docker, YAML and JSON.

## Dependencies

Required:

```sh
brew install neovim ripgrep fd
brew install --cask ghostty font-jetbrains-mono
```

- **neovim** 0.10+ (developed on 0.12)
- **ripgrep** and **fd** — the LazyVim picker uses them for grep and file
  search. Without them `<leader><space>` and `<leader>/` are slow or empty.
- **ghostty** — the `cmd+` shortcuts depend on its `esc:` keybind action.
  Everything else works in any terminal.

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

## How to install

```sh
git clone <this-repo> ~/.config/nvim
nvim
```

lazy.nvim bootstraps itself on the first start. To get the exact plugin commits
from `lazy-lock.json` instead of the latest versions:

```sh
nvim --headless "+Lazy! restore" +qa
```

Then install the Ghostty config, which is what makes the `cmd+` shortcuts reach
the editor:

```sh
cp -r ~/.config/nvim/setup/ghostty ~/.config/ghostty
```

Restart Ghostty, or press `cmd+shift+,` to reload its config.

Language servers for the stacks you care about:

```sh
nvim --headless "+MasonInstall vtsls tailwindcss-language-server prisma-language-server json-lsp" +qa
nvim --headless "+MasonInstall dockerfile-language-server docker-compose-language-service hadolint yaml-language-server" +qa
nvim --headless "+MasonInstall ruby-lsp erb-formatter erb-lint" +qa   # needs host Ruby
```

Verify a server actually attached by opening a file and pressing `<leader>cl`.

### Prefer the repo somewhere else

If you would rather keep the repo alongside your other projects, clone it there
and symlink:

```sh
git clone <this-repo> ~/code/nvim-config
ln -s ~/code/nvim-config ~/.config/nvim
```

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
| `<leader>uw` | toggle wrap |
| `<leader>uf` | toggle format-on-save |
| `zs` / `ze` / `zH` / `zL` | manual horizontal scrolling |

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
  colorscheme.lua
setup/ghostty/                terminal config: cmd+ keybinds, theme, typography
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
