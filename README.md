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
curl -fsSL https://raw.githubusercontent.com/thadeu/clowk-lazyvim/main/setup/install.sh | bash
```

That clones the repo to `~/.config/clowk-lazyvim` and then re-runs itself from
inside it. `~/.config/nvim` becomes a symlink to that clone.

The location is fixed, **not** taken from wherever the script is run — so every
machine ends up with the same layout, and there is no way to accidentally
install from a stray copy. `CLOWK_DIR` overrides it:

```sh
CLOWK_DIR=~/code/clowk-lazyvim curl -fsSL https://raw.githubusercontent.com/thadeu/clowk-lazyvim/main/setup/install.sh | bash
```

Running `setup/install.sh` from a clone that is not the target still installs to
the target — it says so and carries on. That is what `CLOWK_DIR` is for when you
keep a development checkout somewhere else.

Homebrew's the only thing you install yourself. The script is idempotent —
re-run it any time — and it:

1. installs the missing Homebrew dependencies, and only those, upgrading
   Neovim itself when it is below 0.11
2. measures the Node and Ruby on your host and **skips** the stacks whose
   runtime is too old, instead of failing halfway through
3. symlinks `~/.config/nvim` to the clone, moving an existing config (plus its
   plugin and mason state) to `~/.config/nvim-backup-<timestamp>`
4. installs the plugins at the commits in `lazy-lock.json`
5. installs the language servers and **waits** for them (see `setup/mason.lua`)
6. installs the Ghostty config, merging into an existing one instead of
   clobbering it, and validates the result

It ends on a summary of what is live and what was skipped:

```
==> Summary
    core         neovim 0.12.4, ripgrep, fd
    typescript   node 24.13.0
    rails        ruby 3.4.2
    ghostty      present
    nerd font    present
```

`--minimal` skips the optional tools. The only manual step left is
`gh auth login`, which is interactive.

Verify a server actually attached by opening a file and pressing `<leader>cl`.

## Updating a machine that already has it

The curl one-liner is also the update command — it pulls the existing clone
before re-running, so the same line works on a machine that already has it:

```sh
curl -fsSL https://raw.githubusercontent.com/thadeu/clowk-lazyvim/main/setup/install.sh | bash
```

Run from a local clone, though, `setup/install.sh` does NOT pull — it installs
whatever the clone currently holds. There the update is two steps:

```sh
cd ~/.config/clowk-lazyvim
git pull
./setup/install.sh
```

Re-running is safe: every step checks its own result first, the symlink is left
alone once it points at the clone, and the Ghostty keybinds are re-grafted
between their markers rather than appended again.

To land on a released version instead of the tip of main, use the version
script — it pulls the plugin set that goes with it, which a bare `git pull`
does not:

```sh
./setup/version.sh use v0.1.0
```

Either way, restart Ghostty (or `cmd+shift+,`) so the keybinds reload.

## Dependencies

Three tiers, and the installer treats them differently. The distinction is the
whole reason it can finish on a machine that has no Ruby.

### Core — a failure aborts the install

The config does not work without these, and the script installs them.

| | Why |
| --- | --- |
| **Homebrew** | the only thing you have to install yourself |
| **neovim** 0.11+ | `dropbar.nvim` requires it, and the bundled `nvim-treesitter` is the `main` branch. The script upgrades an older Homebrew neovim on its own. Developed on 0.12 |
| **ripgrep**, **fd** | the LazyVim picker greps and finds files with them. Without them `<leader><space>` and `<leader>/` are slow or empty |
| **tmux** | hosts the `cmd+j` popup. The one core dependency that degrades instead of breaking: without it `cmd+j` falls back to Neovim's own float |

### Stack — a failure skips that slice

Each gates one part of the setup and is reported in the summary at the end.
Install what you are missing and re-run the script to enable it later.

| | Gates | Why the check is a version, not a presence test |
| --- | --- | --- |
| **node** 20+ | `vtsls`, tailwind, prisma, json | — |
| **ruby** 3.2+ | `ruby-lsp`, `rubocop` | macOS ships ruby **2.6.10** with a working `gem`, so "is ruby installed" answers yes on a machine where none of these can install. mason's failure there never mentions Ruby |
| **ghostty** | the `cmd+` shortcuts, via its `esc:` keybind action | everything else works in any terminal |
| a **Nerd Font** | icons | LazyVim's file icons, git signs and diagnostics are Nerd Font glyphs; a plain family renders every one as a tofu box. The script installs `font-jetbrains-mono-nerd-font` — **not** `font-jetbrains-mono`, which is the cut without the glyphs — and accepts any Nerd Font you already have |

Node and Ruby are yours to manage: use fnm, mise, asdf, rbenv, whatever. The
script only measures what it finds.

### Optional — a failure is a warning

One feature each. `--minimal` skips them entirely.

| | Unlocks |
| --- | --- |
| **lazygit** | `<leader>gg`. Commit graph, interactive rebase, stage-by-hunk |
| **gh** | the PR/issue pickers and `octo.nvim`. Needs `gh auth login` |
| **claude** | `<leader>gm` (commit messages) and `cmd+option+b` (the sidebar). Uses your Claude Code subscription — no API key |
| a **Copilot** account | `Tab` autocomplete. Free up to 2000 completions a month. Needs `:Copilot auth` once, and node, which the TypeScript stack already installs |
| **mermaid-cli** (`mmdc`) | Mermaid diagrams rendered inline in markdown buffers |
| **imagemagick** (`magick`) | inline svg, pdf and raster images. Not needed for Mermaid |

`brew install mermaid-cli` pulls Homebrew's `node` as a dependency. If you manage
Node with fnm/asdf/mise, yours has to stay first on `PATH` — the script warns
when it does not.

## Installing by hand

The same steps without the script. The order matters: mason cannot install
anything before lazy has cloned it.

```sh
git clone https://github.com/thadeu/clowk-lazyvim.git ~/.config/clowk-lazyvim
ln -s ~/.config/clowk-lazyvim ~/.config/nvim

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
| `cmd+p` | find file by name or folder — same as `<leader><space>` |
| `cmd+b` | toggle the file explorer |
| `cmd+option+b` | Claude Code in a right sidebar, in the project root |
| `cmd+f` | grep the project — same as `<leader>/`, the `g` on the start screen |
| `cmd+shift+f` | find and replace across the project (grug-far) |
| `cmd+z` / `cmd+shift+z` | undo / redo |
| `cmd+/` | toggle comment (line, or the selection in visual) |
| `option+delete` | delete the previous word (insert and `:` / `/` prompts) |
| `option+left` / `option+right` | jump a word back / forward |
| `option+shift+left` / `option+shift+right` | select a word back / forward |
| `option+up` / `option+down` | move the line (or selection) up / down |
| `cmd+left` / `cmd+right` | start / end of line |
| `cmd+shift+left` / `cmd+shift+right` | select to start / end of line |
| `delete` (in normal mode) | delete text without entering insert first |

Shift+arrow selecting is `keymodel=startsel,stopsel` in `lua/config/options.lua`,
not a set of mappings — it is a built-in Vim feature, and it gets the cursor
column right when the selection starts from insert mode. It lands in **visual**
mode, not select mode: in select mode any printable key replaces the selection
(VSCode's behaviour), which would put every Vim operator out of reach.
| `cmd+c` / `cmd+x` | copy / cut to the system clipboard (whole line with no selection) |
| `cmd+v` | paste — Ghostty's own, not remapped (see below) |
| `cmd+j` | toggle a floating terminal, centered, at the project root — a tmux popup ([why](#cmdj-is-a-tmux-popup-not-a-neovim-terminal)) |
| `cmd+w` | close buffer (keeps the window layout) |
| `cmd+n` | new buffer |
| `cmd+\|` | vertical split |
| `option+1..9` | go to tab N (bufferline) — `cmd+1..5` stays Ghostty's tabs |
| `cmd+shift+w` / `cmd+shift+n` / `cmd+shift+c` | Ghostty's own close/new/copy, moved aside |
| `option+double-click` | definition of the symbol in a vertical split |

`cmd+v` is the one key deliberately left alone. Ghostty's `paste_from_clipboard`
already reaches Neovim through bracketed paste — normal mode included, where the
text is inserted rather than run as commands — and forwarding it as `esc:v` would
break pasting in a plain shell for nothing.

`cmd+c` does need forwarding, though: Ghostty would copy the *terminal*
selection, which is not Neovim's visual selection. Mouse selections still land on
the clipboard by themselves, via `copy-on-select`.

### cmd+j is a tmux popup, not a Neovim terminal

Neovim's built-in terminal is a fine place to run `git log`. It is a bad place to
run a full-screen TUI: Claude Code, lazygit at the wrong moment, anything that
redraws its own frame. The redraw lands a row off and the text you type appears
on the box border instead of inside it.

So `cmd+j` opens a **tmux popup** instead — a pty tmux owns and draws over the
pane. Neovim is not in the loop at all, and the TUI inside gets an ordinary
terminal to draw on.

That only works if Neovim is *inside* tmux, which is what the `nvim` wrapper in
`setup/zsh/nvim-tmux.zsh` is for: typing `nvim .` starts a throwaway tmux session
with Neovim in it. Plain shell tabs stay outside tmux, keeping Ghostty's own
scrollback and image protocol. Quitting Neovim ends the session.

Three properties worth knowing, all in `setup/tmux/tmux.conf`:

- **One popup per directory.** The scratch session is named after the path, so
  `packages/core/src` and `packages/hono/src` do not share a shell.
- **It survives.** Closing the popup detaches instead of killing, and the session
  outlives Neovim — quit the editor, come back, and the `claude` you left running
  is still there.
- **The same key closes it.** Inside the popup `cmd+j` detaches that client.

Neovim's float is still mapped, and answers `cmd+j` when you are not in tmux — on
a machine without tmux nothing about the key changes.

`setup/tmux/tmux.conf` is installed **whole**, unlike the Ghostty config, which
is merged into whatever is already on the machine. A tmux config does not merge:
two of them means two `run tpm` lines and a status bar fought over by both. Any
existing `~/.tmux.conf` is moved to `~/.tmux.conf.backup-<timestamp>` and the
repo's takes its place, so a second machine ends up with the splits, the colours
and the plugins — not just the parts this config needs.

The installer also clones tpm and installs the plugins. tpm's own
`bin/install_plugins` hangs when it runs with no tmux client attached, so it gets
one: a detached session on a throwaway socket whose only command is the
installer. Takes about ten seconds, and the socket keeps it away from any tmux
server you already have running.

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
| `<leader>gm` | write the commit message with Claude | `lua/plugins/claude-commit.lua` |

### Other

| Key | Action |
| --- | --- |
| `<leader>H` / `<leader>h` / `<leader>1..9` | harpoon: anchor / menu / jump |
| `<leader>cb` | breadcrumb: pick a segment (or click one) |
| `<leader>uw` | toggle wrap |
| `<leader>uf` | toggle format-on-save |
| `zs` / `ze` / `zH` / `zL` | manual horizontal scrolling |

## AI

Two features, two engines, on purpose.

| Key | Action | Engine |
| --- | --- | --- |
| (as you type) | grey ghost text ahead of the cursor | Copilot |
| `Tab` | accept the suggestion | Copilot |
| `option+]` / `option+[` | next / previous alternative | Copilot |
| `ctrl+]` | dismiss the suggestion | Copilot |
| `<leader>uP` | turn suggestions off / back on | Copilot |
| `<leader>gm` | write the commit message | Claude |
| `cmd+option+b` | Claude Code in a right sidebar | Claude |

### Why two engines

Autocomplete and "write me a commit message" look like one feature and are not.

Completion fires on every pause in typing and is only useful under ~300ms, which
rules out a general-purpose model. Claude is not trained for fill-in-the-middle,
and reaching it for this would need an `ANTHROPIC_API_KEY` billed per token —
**separate from the Claude Code subscription** — so every keystroke would cost
money to answer slower. Copilot's model is small, built for this one job, and
free up to 2000 completions a month.

A commit message is the opposite trade: one deliberate keypress, a few seconds,
and the quality of the answer is the whole point. That is Claude's, and it runs
through the `claude` CLI already on `PATH` — the same binary and the same
subscription as the sidebar — so it costs nothing per call and needs no key.

### Autocomplete

`vim.g.ai_cmp = false` in `lua/config/options.lua` is what makes this behave the
way it does in VSCode. LazyVim defaults it to `true`, which hides Copilot inside
the blink.cmp popup among the LSP entries — where a multi-line suggestion cannot
be shown at all. With it off, three things line up: copilot.lua draws its own
ghost text, blink.cmp turns *its* ghost text off so the two do not overlap, and
blink's `Tab` becomes "accept the AI suggestion, otherwise stay an ordinary Tab".

`Tab` and `Enter` never compete: `Tab` is always Copilot, `Enter` is always the
completion menu. Nothing is ambiguous, which is why the suggestion and the menu
are allowed to be on screen at once.

First run needs `:Copilot auth` (a browser and a device code); the installer
runs it once. `:Copilot status` says whether it took. Copilot leaves `gitcommit`
buffers alone by default — Claude owns those — and also `yaml`, which you can
re-enable with `filetypes = { yaml = true }` in `lua/plugins/copilot.lua` if you
write a lot of CI.

### Commit messages

`<leader>gm` is VSCode's sparkle button, and it means the same thing in the two
places you commit from:

- **in the commit editor**, it writes the message in above git's comment block,
  leaving the block (and the diff under it, on `commit --verbose`) untouched.
  This is the one that matters day to day: `<leader>gg` opens lazygit, `C` there
  opens the commit editor, and snacks starts lazygit with
  `editPreset = "nvim-remote"` — so that editor is not a nested Neovim, it is a
  real buffer in the Neovim you are already sitting in.
- **anywhere else**, it opens a commit buffer of its own, already filled in.
  `ctrl+s` commits, `q` discards. Nothing is written to disk either way: the
  message goes to `git commit -F -` on stdin.

`:ClaudeCommit` is the same thing as a command.

It describes the **staged** diff, and only that. `git diff HEAD` is deliberately
not a fallback — describing unstaged work the commit will not contain is worse
than saying nothing, so with an empty index it tells you to stage first. The one
exception is an amend: git will not open an editor with nothing to commit, so an
empty index *in a commit buffer* means `--amend`, and there it describes `HEAD`.

The prompt sends the last 15 subjects from `git log` as the style reference, and
that single detail is what does most of the work. Nothing describes a project's
commit conventions as accurately as its own log: with it the messages come back
carrying this repo's `feat(tmux):` prefixes and its habit of naming the rejected
alternative, and without it they come back in generic house style.

The call is `sonnet` at `--effort low`, which answers in about 5 seconds.
Measured on this repo: the same call at the default effort takes ~30s for a
message no better, and `haiku` manages to be both slower (~16s) and worse — it
dropped the Conventional Commits prefix every subject here carries. `--safe-mode`
drops CLAUDE.md, skills, hooks and MCP servers for the call, which is mostly
latency but also keeps the output from depending on which project you happen to
be sitting in.

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

**tpm loads plugins where it is called, so "keep tpm last" cuts both ways.**
`set -g status off` placed above `run '~/.tmux/plugins/tpm/tpm'` in
`~/.tmux.conf` is silently undone: dracula turns the status bar back on while
tpm sources it, and `tmux show -g status` answers `on`. The block this repo
grafts is appended *below* the tpm line for that reason — the one thing that has
to override a plugin cannot run before it.

**A tmux popup is a pty; Neovim's terminal is an emulator inside an editor.**
That difference is why `cmd+j` is a popup. In Neovim's terminal buffer, Claude
Code's input box redraws a row off and typed text lands on the border. The same
version in a tmux popup, and in a plain terminal tab, draws correctly.

**Buffer switching costs nothing on the terminal side.**
`option+1..9` needs no Ghostty keybind at all: `macos-option-as-alt` already
makes option arrive as Alt, so `option+1` reaches Neovim as `<M-1>` on its own.
That leaves `cmd+1..5` to Ghostty for switching its own tabs.

Worth knowing if you ever do want a `cmd+N` forwarded: Ghostty ships defaults on
the *physical* key (`super+digit_1=goto_tab:1`) that coexist with the unicode
trigger (`super+1`) in `ghostty +show-config`, and binding only `super+one`
leaves `cmd+1` switching the Ghostty tab instead of reaching Neovim. Both have to
be bound.

The same trap catches any binding that holds **option**, and it caught
`cmd+option+b`: option changes the character macOS reports for the key —
option+b is `∫` — so a `super+alt+b` trigger can miss entirely. `super+alt+key_b`
matches the physical key whatever character came out of it, so both are bound.
Related: `macos-option-as-alt = left` means only the LEFT option counts as Alt,
so these combos do nothing on the right one.

**Ghostty already binds `option+left` and `option+right` — to `esc:b` / `esc:f`.**
Which, with `cmd+b` on the explorer and `cmd+f` on grep, means option+left would
have opened the file tree. Anything forwarded through `esc:` collides with a
plain option+key that produces the same letter, so `ghostty +show-config` is
worth reading before adding one.

**`<C-Left>` and `<C-Right>` are taken by LazyVim, for window resizing.**
That rules out the tidy version of option+arrow — forwarding it as ctrl+arrow so
Vim's built-in word motions handle it — because option+left would resize the
split. `<C-S-Left>` / `<C-S-Right>` ARE free, so the shifted half still gets to
be native. The unshifted half is mapped by hand.

**A pty test cannot verify `option+delete`.**
Feeding `ESC` + `DEL` to nvim through `script` proves nothing: `DEL` is the tty's
erase character, so the line discipline eats the `ESC` before nvim sees it. Every
other sequence here was verified that way and resolved exactly as expected;
option+delete instead sidesteps the question by sending `^W`, which already
means delete-previous-word in both nvim and the shell.

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
Its list starts empty, so `<leader>1` with nothing anchored does nothing — which
reads as a bug. `option+1..9` uses bufferline (position = the tab you see). Harpoon
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
                              ruby, docker, yaml, markdown, harpoon2, octo,
                              copilot
  keymaps.lua                 cmd+ shortcuts, horizontal scroll off, blame toggle
  options.lua                 sidescrolloff / sidescroll, ruby lsp, ai_cmp
  autocmds.lua                (empty -- kept for your own autocmds)
lua/plugins/
  git.lua                     inline blame, diffview
  octo.lua                    picker -> snacks
  markdown.lua                snacks.image for inline mermaid / math
  harpoon.lua                 note on harpoon vs bufferline
  breadcrumb.lua              dropbar: VSCode-style path in the winbar
  claude.lua                  cmd+option+b: Claude Code in a right sidebar
  claude-commit.lua           <leader>gm: the commit message, written by Claude
  copilot.lua                 Tab autocomplete: ghost text, and why not Claude
  colorscheme.lua
setup/
  install.sh                  one-shot installer, idempotent
  version.sh                  release / roll back, on git tags
  mason.lua                   installs the language servers and waits for them
  ghostty/                    terminal config: cmd+ keybinds, theme, typography
  tmux/                       the whole ~/.tmux.conf: popup, splits, plugins
  zsh/                        the nvim wrapper, grafted into ~/.zshrc
```

## Versions and rollback

Every release is a git tag, and `setup/version.sh` is the front end:

```sh
./setup/version.sh                 # what is installed right now
./setup/version.sh list            # every version, newest first
./setup/version.sh release v0.2.0  # tag the current commit and push it
./setup/version.sh use v0.1.0      # roll everything back to that version
./setup/version.sh use main        # back to the tip of main
```

A version is the config **and** the plugin set. `use` checks out the tag
(detached, on purpose — a version is a fixed point) and then replays the
`lazy-lock.json` committed with it, so the plugins go back to the commits that
version was tested against. It also re-grafts that version's Ghostty keybinds
into your terminal config, keeping your own preferences.

Language servers are the one thing not rolled back — mason keeps whatever is
installed. Run `./setup/install.sh` if a version needs a different set.

## Out of scope

Shell (`.zshrc`) and git (`.gitconfig`) configuration are intentionally not part
of this repo — it is an editor config, not a full dotfiles setup.

Also not included: a debugger setup. `nvim-dap` is noticeably weaker than
VSCode's debugger for Node and React; keeping VSCode around just for debugging
sessions, or using `node --inspect` with Chrome DevTools, is the pragmatic call.

Nor is Claude on `Tab`. It is the obvious thing to want, given the rest of this
config, and it is the wrong trade — see [Why two engines](#why-two-engines).
Copilot has that key; Claude has everything where thinking beats latency.

## Credits

- [LazyVim](https://github.com/LazyVim/LazyVim) and its starter template, which
  this config is built on.
- `colors/clowk-night.lua` was produced by a third-party generator
  (`clowk-terminal`) rather than written here; check its upstream terms before
  reusing that file.
