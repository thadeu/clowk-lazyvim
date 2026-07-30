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

-- cmd+1..5: switch tab by position, like VSCode. bufferline already draws the
-- tabs at the top, so the shortcut position is the one you see on screen.
--
-- The `true` is bufferline's `absolute` parameter: order by all buffers rather
-- than only the visible ones, otherwise positions shift as the bar scrolls.
--
-- For stable anchors that do NOT move when you open other files, harpoon lives
-- on <leader>1..9 -- see lua/plugins/harpoon.lua.
for i = 1, 5 do
  map_ni("<M-" .. i .. ">", function()
    require("bufferline").go_to(i, true)
  end, "Go to tab " .. i)
end

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
