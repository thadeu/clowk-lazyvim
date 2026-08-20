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
| **mermaid-cli** (`mmdc`) | Mermaid diagrams rendered inline in markdown buffers. `mmdc` draws through a headless Chrome that Homebrew does NOT pull in — without it every render fails with `Could not find chrome-headless-shell`. `npx puppeteer browsers install chrome-headless-shell` (~130 MB) is the second half of this dependency |
| **imagemagick** (`magick`) | inline svg, pdf and raster images. Not needed for Mermaid |
| **ffmpeg** (`ffplay`, `ffprobe`) | seeking and the waveform in the audio player. macOS plays without it, through the built-in `afplay`, but cannot seek |

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
| `cmd+b` | sidebar: the file explorer |
| `cmd+option+b` | Claude Code in a right sidebar, in the project root |
| `cmd+f` | grep the project — same as `<leader>/`, the `g` on the start screen |
| `cmd+shift+f` | sidebar: find and replace across the project (grug-far) |
| `cmd+shift+g` | sidebar: source control — the changed files, with each diff in the editor |
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

### The sidebar

`cmd+b`, `cmd+shift+f` and `cmd+shift+g` are three panels of ONE sidebar, not
three windows. Only one is ever docked on the left, and the row of icons at the
top of it switches between them -- with the mouse, since the row is drawn as
buffer text and a click on it is caught by a global `<LeftMouse>` map.

The column reads as ONE panel, the way VSCode stacks its icons, a gap and a
title inside a single box. It is two windows:

```
╭─────────────────────────────────────────╮  the bar is a WINDOW,
│                                    │  M.bar_height rows tall,
│                                         │  and it draws the lid
│  CHANGES                                │
│                                         │  <- its STATUSLINE row
│  M apps/…/service.go                    │  the panel, sides only
╰─────────────────────────────────────────╯  <- ITS statusline row
```

The seam is a statusline. Every window has one now (`laststatus` is 2, see the
frame section below), so the row between the two windows exists whether or not
anything is put in it -- left alone it would have cut the column in half.
Drawing the two sides of the box through it is what welds the two boxes into
one. The panel below draws only the sides, and its own statusline closes the
bottom.

That row is also the only one available between the label and the tree, the
panel being a different window that starts drawing on its first row. Leaving it
blank is what gives the label the same air above and below it:

The label names the open panel the way VSCode heads its sections: `FOLDERS`,
`SEARCH`, `CHANGES`. The explorer was named after the project directory at
first, which the tree already says on its own first row -- twice in two rows
reads as a bug, not as an answer.

| `M.bar_height` | rows, the seam included |
| --- | --- |
| 5 | lid / buttons / blank / label / seam -- the VSCode look |
| 4 | lid / buttons / label / seam |
| 3 | lid / buttons / seam |

Five and not four: with the label right under the buttons the air was all on
one side of it, and the column read as two halves rather than as one panel.

Four numbers shape the row, all on the module:

| Knob | What it is |
| --- | --- |
| `M.bar_pad` | spaces around the icon *inside* a button -- the lit block on the open one is exactly this padding, not a filled third of the bar |
| `M.bar_gap` | spaces between two buttons |
| `M.bar_indent` | spaces before the first button, and before the label. One column tighter than the gap, so the row lines up with the rows of the panel below instead of sitting visibly right of them |
| `M.bar_height` | rows, the seam included |

What a button *draws* and what it *answers to* are deliberately different: the
click takes half a gap on each side and every row of the bar except the label,
so a small block does not mean a small aim.

Each button is a **third of the panel**, not the two columns of a glyph, which
is what makes them easy to hit. The bar is a real window in the same column
(`nvim_open_win` with `split = "above"`), so it has height, padding, and a
divider -- a `winbar` was the first attempt and is always exactly one row.

Two things that took a while to get right, both worth knowing before touching
this:

- **The click handler is global, not buffer-local.** A buffer-local
  `<LeftMouse>` on the bar never fires: Neovim resolves the mapping in the
  buffer that is *already* current, and moving to the clicked window is what the
  default `<LeftMouse>` does afterwards. So a buffer-local map would only answer
  clicks made from inside the bar, which is the one place nobody clicks from.
  It is an `<expr>` map that gives the key back untouched when the click is not
  on the bar.
- **A closed picker is not finished.** Its layout keeps a `WinResized` handler
  alive for one more tick, and taking our window out of the same column reaches
  it after its list is gone (`list.lua: attempt to index field 'picker'`).
  Panels close first, and the bar is rebuilt on the next tick.

The glyph itself cannot be scaled from Neovim -- a cell is a cell. Which glyph
is drawn is `M.icons` in `lua/config/sidebar.lua`; how big it is drawn is
Ghostty's `adjust-icon-height` and the `font-codepoint-map` block in
`setup/ghostty/config`.

The **file** icons get two glyphs replaced, in `lua/plugins/icons.lua`, and the
choice was measured. A terminal fits a Nerd Font glyph to the cell, so what
decides whether an icon towers over the text beside it is the glyph's own aspect
ratio. Every glyph mini.icons hands out was measured against the font this
config ships — 1040 of them — and the Material Design set they nearly all come
from is drawn on one grid: 1233 units wide, every single one. Two were not:

| Glyph | Size | Ratio | Replaced by |
| --- | --- | --- | --- |
| `i_seti_yml` (yaml) | 634 × 1864 | **2.94** | `file-cog`, 1237 × 1366, 1.10 |
| `i_seti_shell` (sh, bash, zsh, …) | 996 × 1863 | **1.87** | `bash`, 1233 × 1060, 0.86 |

A capital `M` in the same font is 1059 × 1488, a ratio of 1.41. Everything else
over 1.5 is a filetype nobody here opens or one of mini.icons' `alpha-*` letters
— the fallback for the hundreds of filetypes with no icon of their own, five
hundred entries at 1.67, which is 18% over the `M` and not worth the churn.

`lua/plugins/bufferline.lua` draws the buffer tabs, and the tabline they live on
is not a tabline any more: it is the row of **lids**. bufferline assembles its
line in a fixed order —

```
offsets.left · custom_areas.left · TABS · custom_areas.right · offsets.right
```

— so a custom area is a way to put something immediately before the first tab
and immediately after the last one, and whatever it measures comes off the width
bufferline has to fill. That is the whole mechanism: the left area draws the
sidebar's lid, the gap column and the editor's corner; the right one draws the
lid of the Claude panel; and the tabs land in between, sized to what is left,
which is the editor.

```
╭─ CLOWK LAZYVIM ──────────────────────╮ ╭─   frame.lua  ⚠1
│                                      │ │  lua › config › frame.lua
│  󰉋  󰍉  󰊢                             │ │  121   --- The left edge, in front of…
╰──────────────────────────────────────╯ ╰─ frame.lua                     125:1
```

Each item carries its own highlight, and the lids have to say their background
out loud: that one line runs over three panels with three backgrounds, and there
is nothing underneath a tabline to inherit from. `always_show_bufferline` is on
because a panel with no lid is a panel with a hole in it.

The sidebar's lid comes from there too, which is why the icon bar starts with a
blank row rather than a border: its box is opened one row above it, by a
different line.

Pressing the key (or clicking the icon) of the panel already on screen closes
the sidebar. Pressing another one swaps the contents.

There is no filter line over the panel: a tree and a list of changed files are
there to be read, not typed at. `/` brings the filter in and focuses it, `<esc>`
puts it away again -- `<esc>` would otherwise close the whole picker, which
inside a sidebar reads as losing the panel to a typo.

The source control panel is the one worth explaining. The list of changed files
is narrow, but the **diff is not**:

| Key | What you get |
| --- | --- |
| `j` / `k` | the unified diff of the file under the cursor, in the editor window |
| `<cr>` | the **two-pane diff**: the index on the left, the working tree on the right |
| `o` | the file itself, no diff |

`<cr>` twice on two different files replaces the diff rather than stacking a
third pane, and closing the left pane takes the diff mode of the right one with
it. An untracked file has no other side, so `<cr>` there just opens it.

The file is looked for in the tab rather than assumed to be under the cursor:
with `preview = "main"` the editor window still holds the preview buffer for a
tick or two after the jump, the file may already be open in another window, and
a click leaves the cursor where it clicked. If it never turns up, or the file is
not in the index, the panel says so instead of doing nothing.

The two panes are built here (`git show :0:<path>` into a scratch buffer) and
not with `Gitsigns diffthis`, which looks like the ready-made answer and is not:
gitsigns diffs the buffer you are *already* sitting in, and only once its own
asynchronous read of the index has finished. On a file opened a millisecond
earlier it fails with `assertion failed!` inside its async runner, where no
pcall can reach it.

The panel key is not a plain toggle either. Closed, it opens; open but with the
cursor elsewhere (right after `<cr>` the cursor is in the diff), it takes you
back to the panel; open and focused, it closes.

Find and replace is *hidden* rather than closed, so the search text and the
results survive until the next time you open it.

lazygit is deliberately NOT one of the panels -- it stays the full-screen float
on `<leader>gg`. Its four panels need the whole window, which is the one thing a
40-column sidebar cannot give.

The whole thing is `lua/config/sidebar.lua`.

### The gap between the panels

VSCode draws editor, sidebar and secondary sidebar as separate cards, with a
strip of app background between them. Half of that survives the trip into a
terminal and half does not: the smallest thing Neovim can paint is one cell, so
a corner radius is always a glyph and never a curve — but the strip is real,
because the column Neovim already draws between two vertical splits is exactly
one cell wide.

Two options make it, and which half of each is used is the whole trick:

| | |
| --- | --- |
| `fillchars` | the CHARACTER of the column. A space has no glyph, so the cell is nothing but its background |
| `WinSeparator` | the colour — and only its `bg` is taken. The `fg` is still the horizontal rule between stacked windows, the one under the icon bar in the sidebar, so painting the gap with `fg` would have erased that rule in the same stroke |

`fillchars` is a global-*local* option, which is why the setting has two halves.
A window that sets its own value stops reading the global one, and snacks sets
one on every window it owns. The separator between two splits is drawn by the
window on the **left** of it — so the sidebar, a snacks window, was the last
split still drawing a `│` after every other one had gone quiet.
`lua/plugins/panels.lua` hands the same value to `Snacks.config.win`, which
every snacks window resolves against, including the box that a split layout is
wrapped in. That box, and not the list inside it, is the window that touches the
editor.

The colour is derived rather than written down, because `colors/clowk-night.lua`
is generated by clowk-terminal and is overwritten whole on every regeneration.
The gap is the darker of `Normal` and `NormalFloat`, darkened again — `DEPTH` in
`lua/config/panels.lua` is the knob, and `1.0` makes the gap disappear.

### The frame around each panel

The gap separates the panels; this draws a rounded box around each one, the way
lazygit frames every one of its own. lazygit can do it because it owns every
cell of the screen. A Neovim window does not get that canvas, and the box it
*can* draw by itself — the four-sided border of a floating window — is out of
reach here: a float cannot be split (`Cannot split a floating window`), and the
editor is nothing but splits.

What a window does give away is three of its four edges, and all three are
decorations Neovim already renders around the text:

| Edge | Drawn by | Carries |
| --- | --- | --- |
| top | the `tabline` | the lid of every panel at once, with the buffer tabs inside the editor's |
| left | `statuscolumn` | in front of the line numbers, and the `winbar` on its own row |
| bottom | `statusline` | lualine, between the two corners |
| right | a window one column wide | nothing but the border — see below |

Two rows of chrome inside a panel — tabs, then the breadcrumb under them — is one
row more than a window has: `winbar` is a single line and so is `statusline`.
The tabline is the only other line on offer, and being screen-wide is exactly
what lets it draw a lid over every column at once.

The fourth edge is not a decision, it is a wall. A window can reserve a cell on
its **left** — that is what `statuscolumn` is — and has nothing of the kind on
its right. The only column there is the separator, and the separator belongs to
the layout rather than to the window: it sits one cell further right than the
corner a winbar can reach, so the two would never meet. `colorcolumn` paints a
column instead of reserving one and looked like the way out, but it only paints
where a buffer LINE is — past the end of the file it draws nothing, which is
most of the screen on a start page.

The one thing that *does* own a column is a window, so the fourth edge is one.
`lua/config/margin.lua` keeps a window one cell wide on the far right and fills
its buffer with `│`. The top corner comes from the tabline, the line from that
buffer, the bottom corner from that window's own statusline.

It is a window that is not yours, and it behaves like one: it turns up in
`<C-w>` cycling (WinEnter bounces straight back out), `:only` deletes it
(WinClosed puts it back), and closing the last real window would leave Neovim
sitting there showing one column of frame — it quits instead, the last window
being the one thing that cannot be closed, only quit.

Two windows cannot touch, so there is a separator between the panel and its own
border, and what that column is *painted* with turned out to be the whole
difference between a frame and a stripe. With the gap's dark background — which
is right for every other separator in the layout — the border read as something
stuck to the side of the screen; with the panel's, as a second thin panel
stranded out there. It is given no background at all instead, along with the
border column itself, and that column becomes the padding before the edge, which
is what the left side has had all along. `winhighlight` does it on the window to
the LEFT, since that is the window that draws the separator, and only for that
one: every other gap in the layout stays a gap.

The panels that had a right side all along keep theirs: the tree, because snacks
draws it a real border, and the icon bar, because those two columns are its own
buffer text.

Three details make the rest cheap:

- **The top edge stretches itself.** `fillchars` has `wbr`, the character the
  winbar pads itself with. Set it to `─` and a `%=` in the middle of the line
  runs the border out to the exact width of the window. No arithmetic, and
  nothing to redo on a resize.
- **The bottom edge cannot.** The statusline has the same padding — `stl` and
  `stlnc` — and it is unreachable: lualine emits the highlight of the MIDDLE
  section immediately before its `%=` (`format_highlight('c') .. '%=' ..
  section_data`, hardcoded), so the run of `─` comes out in the colour of the
  file path. Near white, and a bright line under every panel. The panels that
  are not the editor therefore draw their whole bottom edge as one component
  with the width measured; the editor keeps its lualine content between the two
  corners, a footer inside the box the way lazygit's bottom bar sits inside its
  frame.
- **dropbar stands down on its own.** Its `enable` refuses any window that
  already has a winbar, so setting the frame first is all it takes — and
  `v:lua.dropbar()` inside the frame still builds the bar on demand, clicks and
  menus included.
- **`winbar` is global-*local*, and that one is a trap.** For a string option of
  that kind an empty local value does not mean "no winbar", it means "use the
  global one". A frame set globally is therefore worn by every window that turns
  its winbar off — snacks' own among them, which is exactly the set that must
  not have it. It is set per window instead.

`laststatus` goes from 3 to 2 for this: the bottom edge belongs to the panel,
not to the screen. lualine follows that number by itself, and the panels that
are not the editor get a lualine *extension* — it is what lets them replace the
whole line with their edge, and without it lualine writes `[No Name] [-] 1:1`
under a file tree, where the row is not a status but the bottom of a box.

The panels each close what they can. The whole left column is one box drawn by
two windows: the icon bar puts a lid and two sides on it in its own buffer text,
its statusline is the title row under the buttons, the tree below carries the
two sides on — a snacks layout, wrapped in a split precisely so it can carry a
border, here asked for the sides and nothing else — and the tree's statusline
closes the bottom. Claude asks for `frame.top(" claude ")` and puts a title
where the breadcrumb would go.

Find and replace is the one panel that cannot close: grug-far opens a plain
window, so it has the wall on its right, and the rows it draws as virtual lines
have no gutter to carry the left edge either.

The start screen needed three of its own. The left edge rides on the gutter,
and the dashboard turns its `statuscolumn` off, so its box came out with a top,
a bottom, two corners and nothing between them -- an empty `statuscolumn` is
read as "no gutter here" and the edge goes into that column alone. snacks also
hides both bars while the dashboard is up (`vim.o.showtabline, vim.o.laststatus = 0, 0`), which takes the
name off the tabline and the bottom edge off the panel on the one screen that is
nothing but panels -- so they are put back when it opens, and its buffer is
named in the short list of non-files that still get a frame. Its own restore on
close is written as "only if still 0", so this does not fight it.

The breadcrumb is called through a wrapper rather than as the `v:lua.dropbar()`
the plugin writes, because dropbar is lazy-loaded on the first FILE and `nvim .`
opens on a directory: a dashboard and a tree, no file anywhere. The winbar drew,
the call failed, and every redraw of the picker raised `attempt to call global
'dropbar'`.

`lua/config/frame.lua`, `lua/plugins/lualine.lua`.

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

**Copying text out of the popup** is the one thing a popup makes harder, and it
fails in two different ways, neither of which reports itself:

| | |
| --- | --- |
| Dragging with the mouse selects nothing | tmux does not route mouse events into a popup. The same drag in an ordinary pane selects and copies |
| A copy inside the popup never reaches macOS | OSC 52 — the escape sequence `set-clipboard` uses, and what carries a copy out of an ordinary pane — does not survive the popup either |

So there are two ways in, and both are set up:

- **Mouse:** hold **shift** while dragging. Shift makes Ghostty ignore tmux's
  grab on the mouse and select with its own selection, and `copy-on-select =
  clipboard` puts it on the clipboard with no `cmd+c`. It is also the only way
  to select text that crosses the popup border.
- **Keyboard:** `ctrl+b [` enters copy mode, `v` starts the selection, `y` takes
  it. `y` pipes through `pbcopy`, a local process, which is why it works where
  OSC 52 does not. Copy mode is `mode-keys vi`, so `v`, `y` and `/` mean what
  they mean in Neovim.

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
| `cmd+shift+g` | changed files in the sidebar, diff in the editor | `lua/config/sidebar.lua` |
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
path in the **winbar** — the row under the lid, directly below the buffer tabs,
which is where VSCode has it:

```
│  lua › config › frame.lua › set_hl
```

It starts on the **line numbers**, so the gutter and the path share a left edge.
Where the numbers begin is not a constant — they are right-aligned in their
field, so a two-digit line starts a column further right than a three-digit one,
and the field itself moves when a sign column appears. Rather than guess at any
of that the statuscolumn is *rendered* and the first digit found in it:
`nvim_eval_statusline` draws it for whichever line is asked for, and the width of
everything before that digit is the column to start on. The line asked for is
the one at the top of the window, so the path lines up with the numbers actually
on screen; the widest number in the file was the first answer and left the path
one cell off in any long file scrolled past its first hundred lines. dropbar's
own left padding is set to zero, because two hands on the same indent fight.

The cut is aimed, too: a `%<` right after the edge is the truncation *point*, so
a path too long for a narrow split loses its leftmost segments instead of its
frame. Without it the split came out with a `<` where its left edge belongs.

It builds the path from LSP `documentSymbol`, treesitter and the file path, in
that order. Every segment is clickable and opens a menu to jump; `<leader>cb`
does the same from the keyboard.

Names only, and a chevron with a column of its own:

dropbar puts three kinds of icon in that line — one for the file, one for a
directory, one per LSP symbol kind — so a path five segments long carries five
glyphs competing with the five words that mean something. They are spelled empty
one kind at a time, from dropbar's own list, rather than through its
`icons.enable = false`: that switch blanks `icons.ui` as well, where the
separator lives, and does it by metatable — which `vim.tbl_deep_extend` drops on
the way through, leaving the bar with nil where it wants a string.

The chevron is a *text* one (`›`) and not the Nerd Font glyph dropbar ships. A
Nerd Font glyph is an icon as far as the terminal is concerned, and a terminal
fits icons to the cell: Ghostty does, iTerm2 does not, which is why the same
file icons look inflated in one and right in the other. Ordinary text is drawn
as text in both.

The symbol part used to be duplicated between the winbar and the statusline.
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

Run `:checkhealth snacks` to see which external tools were detected — and
which terminal. Inside tmux that detection is a trap worth knowing about:
snacks asks tmux for `client_termname`, which is the TERM the outer terminal
announced, and the Ghostty config announces `xterm-256color`. snacks then finds
no "ghostty" in that name, decides the terminal cannot draw, and every image
falls back to text without saying why. `lua/config/options.lua` sets
`SNACKS_GHOSTTY`, which is snacks' own escape hatch, and spells the chain out.

**`markdownlint` is off on purpose.** The `lang.markdown` extra wires
`markdownlint-cli2` in twice — as a linter that runs on every save, and as a
formatter that runs `--fix` while one of its diagnostics is open — and its rules
police the shape of the file (line length, inline HTML, duplicate headings)
rather than whether it reads well. Prose written normally lights the buffer up,
and the auto-fix then rewrites lines nobody touched straight into the next
`git diff`. `marksman` still reports broken links and references, and
`prettier` stays in the formatter chain — but nothing installs `prettier` here,
so on a clean machine no tool rewrites a markdown buffer on save any more.
`:ConformInfo` shows the chain; `lua/plugins/markdown.lua` says how to bring the
linter back.

**Spell check is off too**, for the same reason and by a different route. It is
easy to mistake for a linter: LazyVim's `wrap_spell` autocmd sets `spell = true`
for markdown, and `SpellBad` is a red undercurl — the same mark a diagnostic
uses. A README full of product names, CLI flags and code spans then reads as a
file full of errors. `lua/config/autocmds.lua` puts `spell` back to `false` for
text, plaintex, typst, gitcommit and markdown, and keeps the `wrap = true` half
of that autocmd. `<leader>us` turns spelling back on for one buffer.

## Images and audio

Opening a `.png` or a `.mp3` in a plain Neovim reads the raw bytes into a buffer
and fills the screen with binary garbage. Both file types are taken over before
that happens, by the same mechanism — `BufReadCmd`, the autocmd that REPLACES
the read of a file — and something else is drawn instead.

**Images** cost nothing extra: the `snacks.image` already enabled for Mermaid is
also a viewer. `:e logo.png`, or picking one in the sidebar, draws the picture
in the buffer through the Kitty graphics protocol, which Ghostty implements.

| | |
| --- | --- |
| Formats | png, jpg, jpeg, gif, bmp, webp, tiff, heic, avif, icns, pdf, and the first frame of mp4, mov, avi, mkv, webm |
| Not included | `svg` — it is source code, and taking it over would make every svg in a repo unopenable for editing. `lua/plugins/markdown.lua` says how to trade that away |
| Needs | `magick` for everything that is not already a PNG |

**Audio** has no upstream plugin, so `lua/config/audio.lua` is one: a player
buffer, with the waveform doubling as the seek bar.

```
  󰋅  song.mp3
  mp3 · 44.1 kHz · stereo · 128 kbps · 3.4 MB

      ▄▄▄█▄▄▄▄           ▄▄▄▄▄▄▄           ▄▄▄▄▄▄▄▄           ▄▄▄█▄▄▄▄
   ▄███████████▄      ▄███████████▄      ▄██████████▄▄     ▄▄██████████▄
 ▄███████████████▄  ▄███████████████▄  ▄███████████████▄ ▄███████████████▄
███████████████████████████████████████████████████████████████████████████
███████████████████████████████████████████████████████████████████████████
 ▀███████████████▀  ▀███████████████▀  ▀███████████████▀ ▀███████████████▀
   ▀███████████▀      ▀███████████▀      ▀██████████▀▀     ▀▀██████████▀
      ▀▀▀█▀▀▀▀           ▀▀▀▀▀▀▀           ▀▀▀▀▀▀▀▀           ▀▀▀█▀▀▀▀

  ▶  01:23 / 03:45   vol 80
```

The played part of the waveform is highlighted, and a click anywhere on it
seeks there.

| Key | |
| --- | --- |
| `space`, `enter`, `p` | play / pause |
| `h` `l`, `←` `→` | ∓5 seconds |
| `H` `L` | ∓30 seconds |
| click | seek to that point of the waveform |
| `0` | back to the start |
| `s` | stop |
| `-` `=` | volume |
| `m` | mute |
| `r` | repeat |
| `q` | close |

| | |
| --- | --- |
| Formats | mp3, wav, m4a, aac, aif, aiff, caf, flac, ogg, oga, opus, wma |
| Plays with | `ffplay` (from ffmpeg). Without it, macOS's built-in `afplay` — which has no start-offset flag, so seeking is the one feature that goes away |
| Waveform | `ffmpeg`. Without it the seek bar is a flat line, and everything else still works |
| Duration and the format line | `ffprobe`, or `afinfo` on macOS |

Pausing is `SIGSTOP`: neither player has a pause command, so the process is
frozen mid-buffer and `SIGCONT` picks the sound up where it was. Seeking is a
restart at an offset, which is why it needs `ffplay`.

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
  options.lua                 absolute line numbers, sidescrolloff /
                              sidescroll, ruby lsp, ai_cmp
  autocmds.lua                spell check off for prose; registers the audio
                              player early enough to beat the read of
                              `nvim song.mp3`
  audio.lua                   the .mp3 / .wav player: waveform, seek bar, keys
  sidebar.lua                 the activity bar: layout, icon row, panels
  panels.lua                  the dark gap between the panels
  frame.lua                   the rounded box around each panel
  margin.lua                  the fourth edge: a window one column wide
lua/plugins/
  git.lua                     inline blame, diffview
  octo.lua                    picker -> snacks
  markdown.lua                snacks.image for inline mermaid / math
  panels.lua                  the gap again, for the windows snacks owns
  lualine.lua                 the bottom edge of every box
  icons.lua                   two file glyphs, replaced by measurement
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
