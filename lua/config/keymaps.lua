-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- VSCode-inherited shortcuts.
-- Ghostty rewrites cmd+X into ESC+X (see setup/ghostty/config), which Neovim
-- receives as <M-X>.
local map = vim.keymap.set

--- Register a binding in BOTH normal and insert mode.
---
--- Insert mode is not optional here: if <M-w> only exists in normal mode, the
--- ESC+w that Ghostty sends matches no mapping at all -- the ESC just leaves
--- insert mode and `w` runs as a word motion.
---
--- `stopinsert` + `vim.schedule` make the action run once we are already out of
--- insert mode; deleting the buffer while the cursor is in insert leaves Neovim
--- in a weird state.
local function map_ni(lhs, fn, desc)
  map("n", lhs, fn, { desc = desc })
  map("i", lhs, function()
    vim.cmd("stopinsert")
    vim.schedule(fn)
  end, { desc = desc })
end

-- cmd+j: toggle the terminal. Includes terminal mode, so it closes from inside.
map({ "n", "i", "t" }, "<M-j>", function()
  Snacks.terminal.toggle(nil, { cwd = LazyVim.root() })
end, { desc = "Terminal (toggle)" })

-- cmd+w: close the buffer WITHOUT tearing down the window layout (`:bd` would).
map_ni("<M-w>", function()
  Snacks.bufdelete()
end, "Close buffer")

-- cmd+n: new buffer
map_ni("<M-n>", function()
  vim.cmd("enew")
end, "New buffer")

-- cmd+| : vertical split
map_ni("<M-\\>", function()
  vim.cmd("vsplit")
end, "Vertical split")

-- option+1..9: switch tab by position. bufferline already draws the tabs at the
-- top, so the shortcut position is the one you see on screen.
--
-- This is NOT a LazyVim default -- nothing in LazyVim or its plugins binds
-- <M-1>. The loop below is what creates it. Ghostty sends option as Alt
-- (`macos-option-as-alt = left`), so option+1 arrives as <M-1> with no keybind
-- on the terminal side; cmd+1 is left to Ghostty for switching ITS tabs.
--
-- The `true` is bufferline's `absolute` parameter: order by all buffers rather
-- than only the visible ones, otherwise positions shift as the bar scrolls.
--
-- For stable anchors that do NOT move when you open other files, harpoon lives
-- on <leader>1..9 -- see lua/plugins/harpoon.lua.
for i = 1, 9 do
  map_ni("<M-" .. i .. ">", function()
    require("bufferline").go_to(i, true)
  end, "Go to tab " .. i)
end

-- cmd+b: toggle the file explorer, like VSCode's sidebar.
map_ni("<M-b>", function()
  Snacks.explorer()
end, "Explorer (toggle)")

-- cmd+p: find files by name or folder. The picker matches against the whole
-- relative path, so `config/key` finds lua/config/keymaps.lua.
--
-- cmd+f: grep the project.
--
-- Both go through LazyVim.pick rather than calling Snacks directly: it resolves
-- to whichever picker is configured and applies LazyVim's root detection, so
-- these stay exactly <leader><space> and <leader>/ -- the same two the start
-- screen offers -- instead of drifting from them.
map_ni("<M-p>", LazyVim.pick("files"), "Find file")
map_ni("<M-f>", LazyVim.pick("live_grep"), "Grep project")

-- cmd+shift+f: find and replace across the project. grug-far ships with
-- LazyVim (also on <leader>sr) and edits the results buffer in place.
map_ni("<M-F>", function()
  require("grug-far").open({ prefills = { paths = LazyVim.root() } })
end, "Find and replace (project)")

-- cmd+c / cmd+x: copy and cut to the SYSTEM clipboard ("+), so the text is
-- available to every other app.
--
-- With no visual selection they act on the whole line, matching VSCode.
--
-- cmd+v is deliberately NOT mapped here: Ghostty's own paste already works
-- everywhere (including normal mode, via bracketed paste), so it stays native
-- and keeps working in the shell too.
map("v", "<M-c>", '"+y', { desc = "Copy to clipboard" })
map("v", "<M-x>", '"+d', { desc = "Cut to clipboard" })
map_ni("<M-c>", function()
  vim.cmd('normal! "+yy')
end, "Copy line to clipboard")
map_ni("<M-x>", function()
  vim.cmd('normal! "+dd')
end, "Cut line to clipboard")

-- cmd+z / cmd+shift+z: undo and redo.
--
-- From insert mode these go through map_ni, which leaves insert first. That is
-- also what makes the undo granularity match VSCode: leaving insert closes the
-- undo block, so one cmd+z takes back the burst you just typed rather than the
-- whole time you spent in insert mode.
map_ni("<M-z>", function()
  vim.cmd("undo")
end, "Undo")
map_ni("<M-Z>", function()
  vim.cmd("redo")
end, "Redo")

-- cmd+/: toggle comment.
--
-- `remap = true` is required: gcc/gc are themselves mappings (Neovim's built-in
-- commenting), and the default nore- would send the literal keys to nothing.
map("n", "<M-/>", "gcc", { remap = true, desc = "Toggle comment" })
map("v", "<M-/>", "gc", { remap = true, desc = "Toggle comment" })
map("i", "<M-/>", function()
  vim.cmd("stopinsert")
  vim.schedule(function()
    vim.cmd("normal gcc")
  end)
end, { desc = "Toggle comment" })

-- option+delete: delete the word before the cursor, like every macOS text field.
--
-- Ghostty sends ^W for it, which insert and command mode already understand, so
-- the real work is in setup/ghostty/config. This mapping is the fallback for
-- the RIGHT option key, which `macos-option-as-alt = left` leaves composing
-- accents and which sends ESC + DEL -- <M-BS> -- instead.
map({ "i", "c" }, "<M-BS>", "<C-w>", { desc = "Delete previous word" })

-- Arrow keys, macOS style.
--
-- Only the cmd+ ones need Ghostty's help. option+arrow already arrives on its
-- own, and cmd+left/right are forwarded as Home/End, whose meaning Neovim
-- already knows -- so the whole cmd+arrow family needs no mapping here at all:
--
--   cmd+left / cmd+right              <Home> / <End>
--   cmd+shift+left / cmd+shift+right  <S-Home> / <S-End>, selecting via keymodel
--
-- What is left is option+left / option+right, which arrive as <M-Left> and
-- <M-Right>. The SHIFTED pair needs nothing here: Ghostty forwards it as
-- ctrl+shift+arrow, which Vim answers natively once keymodel is set.
--
-- The obvious shortcut -- forwarding the unshifted pair as ctrl+arrow too, so
-- Vim's built-in word motions handle it -- does not work: LazyVim binds
-- <C-Left> / <C-Right> to shrink and grow the window, so option+left would
-- resize the split. Hence real motions here.
--
-- In insert mode <C-Left> IS safe (LazyVim's resize maps are normal-mode only),
-- and it is the built-in insert word motion, so remap onto it there.
map({ "n", "x" }, "<M-Left>", "b", { desc = "Word left" })
map({ "n", "x" }, "<M-Right>", "w", { desc = "Word right" })
map("i", "<M-Left>", "<C-Left>", { remap = true, desc = "Word left" })
map("i", "<M-Right>", "<C-Right>", { remap = true, desc = "Word right" })

-- Fallback for a right option key that is also configured as Alt: it sends
-- ESC-prefixed shifted arrows, which never pass through Ghostty's keybind.
map({ "n", "x", "i" }, "<M-S-Left>", "<C-S-Left>", { remap = true, desc = "Select word left" })
map({ "n", "x", "i" }, "<M-S-Right>", "<C-S-Right>", { remap = true, desc = "Select word right" })

-- option+up/down: move the line (or the selection) up and down.
--
-- These are LazyVim's <A-j>/<A-k>, spelled out rather than remapped onto them:
-- <A-j> is the same key as <M-j>, which cmd+j took over for the terminal
-- toggle, so LazyVim's "Move Down" no longer exists to delegate to.
--
-- The `==` re-indents the line after the move, and `gv=gv` does it for a
-- selection while keeping the selection.
map("n", "<M-Down>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move line down" })
map("n", "<M-Up>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move line up" })
map("i", "<M-Down>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move line down" })
map("i", "<M-Up>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move line up" })
map("v", "<M-Down>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move line down" })
map("v", "<M-Up>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move line up" })

-- delete (backspace): delete text straight from normal mode.
--
-- Vim's <BS> in normal mode only moves the cursor left, which is the one place
-- the key does nothing useful. `X` deletes the character before the cursor,
-- matching what the key does in every other macOS app, and in visual mode it
-- deletes the selection.
map("n", "<BS>", "X", { desc = "Delete previous character" })
map("x", "<BS>", "d", { desc = "Delete selection" })

-- Inline blame toggle: <leader>uB
--
-- gitsigns runs `git blame` per line. On large files with long history that can
-- add noticeable latency while moving around, and this turns it off instantly
-- without editing config.
--
-- LazyVim has no built-in blame toggle -- <leader>ub is light/dark background.
-- This one is hand-rolled with Snacks.toggle.
Snacks.toggle({
  name = "Git Blame (line)",
  get = function()
    return require("gitsigns.config").config.current_line_blame
  end,
  set = function(state)
    require("gitsigns").toggle_current_line_blame(state)
  end,
}):map("<leader>uB")

-- Trackpad horizontal scrolling: disabled.
--
-- macOS trackpads emit horizontal scroll events from any sideways drift of the
-- finger. With `wrap = false` Neovim shifts the window sideways and it STAYS
-- there until the cursor forces it back -- lines shorter than the offset render
-- empty, and the file looks like scattered fragments.
--
-- Shift + vertical scroll also scrolls horizontally in Vim, hence those too.
-- To scroll sideways on purpose: zH / zL (half screen), zs / ze (align cursor).
for _, key in ipairs({
  "<ScrollWheelLeft>",
  "<ScrollWheelRight>",
  "<S-ScrollWheelLeft>",
  "<S-ScrollWheelRight>",
  "<S-ScrollWheelUp>",
  "<S-ScrollWheelDown>",
}) do
  map({ "n", "i", "v", "t" }, key, "<Nop>", { desc = "Horizontal scroll disabled" })
end

-- option+double-click: open the definition of the symbol under the cursor in a
-- vertical split (the equivalent of VSCode's option+click).
--
-- The cursor has to be repositioned by hand: mapping the click replaces the
-- default cursor-positioning behaviour with ours.
map("n", "<A-2-LeftMouse>", function()
  local pos = vim.fn.getmousepos()
  -- winid 0 = outside any window; line 0 = statusline, tabline or border
  if pos.winid == 0 or pos.line == 0 then
    return
  end
  vim.api.nvim_set_current_win(pos.winid)
  vim.api.nvim_win_set_cursor(pos.winid, { pos.line, math.max(pos.column - 1, 0) })
  vim.cmd("vsplit")
  vim.lsp.buf.definition()
end, { desc = "Definition in vertical split" })
