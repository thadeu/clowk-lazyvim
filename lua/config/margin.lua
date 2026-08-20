-- The fourth edge: a window one column wide, on the far right, whose text is
-- the right border of the panel beside it.
--
-- lua/config/frame.lua explains why it takes a window. A window can reserve a
-- cell on its LEFT -- that is what `statuscolumn` is -- and has nothing of the
-- kind on its right; `colorcolumn` paints instead of reserving and only paints
-- where a buffer LINE is, so it draws nothing past the end of a file, which is
-- most of a start screen; and the separator column belongs to the layout rather
-- than to the window, one cell further right than any corner a winbar can
-- reach. The one thing that owns a column is a window, so here is one.
--
-- What it costs is a window that is not yours: it turns up in `<C-w>` cycling
-- (WinEnter bounces straight back out), `:only` deletes it (WinClosed puts it
-- back), and closing the last real window would otherwise leave Neovim running
-- with nothing but a column of border on screen (it quits instead -- the last
-- window cannot be closed, only quit).
--
-- What it buys is the only closed box in the layout: the top corner comes from
-- the tabline (lua/plugins/bufferline.lua), the line from this buffer, and the
-- bottom corner from this window's own statusline (lua/plugins/lualine.lua).
--
-- The border sits one column past the panel, with the separator's gap between
-- them, because two windows cannot share a column. That is the compromise, and
-- it is the whole of it.

local M = {}

M.filetype = "clowk_margin"

--- The column itself. One cell, three bytes.
local EDGE = "│"

---@type integer? the buffer, reused across windows
local buf

---@type integer? the window whose separator was made invisible, so it can be
--- given back when the layout moves it away from the border
local seamed

--- The window in this tabpage, or nil.
---@return integer?
function M.win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(win)

    if vim.api.nvim_win_is_valid(win) and vim.bo[b].filetype == M.filetype then
      return win
    end
  end
end

--- Enough `│` to fill the window, refreshed when its height changes.
---
--- Buffer text and not virtual text: virtual text hangs off a LINE, and the
--- rows past the end of a buffer have none -- the same wall that ruled out
--- `colorcolumn`.
local function fill(win)
  local height = vim.api.nvim_win_get_height(win)
  local lines = {}

  for i = 1, height do
    lines[i] = EDGE
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

--- Hide the separator between the border and the panel it closes.
---
--- There is always one: two windows cannot touch. Painted with the gap's dark
--- background -- which is what every OTHER separator should look like -- it put
--- a stripe between the panel and its own border, and the border read as
--- something stuck to the side of the screen rather than as the edge of the
--- box. Given the panel's background instead, that column becomes the padding
--- before the border, which is what the left edge has had all along.
---
--- Done through `winhighlight` on the window to the LEFT, because that is the
--- window that draws the separator, and only for that one: every other
--- separator in the layout stays a gap.
local function hide_seam(margin)
  local col = vim.api.nvim_win_get_position(margin)[2]
  local found

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local pos = vim.api.nvim_win_get_position(win)

    if win ~= margin and pos[2] + vim.api.nvim_win_get_width(win) == col - 1 then
      found = win
      break
    end
  end

  if seamed == found then
    return
  end

  if seamed and vim.api.nvim_win_is_valid(seamed) then
    local hl = vim.wo[seamed].winhighlight:gsub(",?WinSeparator:ClowkSeam", "")

    vim.wo[seamed].winhighlight = hl
  end

  seamed = found

  if found then
    local hl = vim.wo[found].winhighlight

    vim.wo[found].winhighlight = hl == "" and "WinSeparator:ClowkSeam" or hl .. ",WinSeparator:ClowkSeam"
  end
end

--- Put the border back if it is missing, and keep it the right height.
function M.ensure()
  if vim.api.nvim_get_current_tabpage() == nil then
    return
  end

  -- Alone in the tabpage, the border is all that is left of it: the last real
  -- window has been closed and Neovim would otherwise sit there showing one
  -- column of frame. It cannot be CLOSED at that point -- the last window never
  -- can, `E444` -- so the tabpage is quit, which is what the `:q` that got here
  -- was asking for.
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local existing = M.win()

  if #wins == 1 and existing then
    pcall(vim.cmd, "quit")

    return
  end

  if existing then
    fill(existing)
    hide_seam(existing)

    return
  end

  if #wins == 0 then
    return
  end

  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].filetype = M.filetype
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
  end

  -- `noautocmd` because this runs FROM an autocmd on window changes, and a
  -- window opening inside that would call it again.
  local win = vim.api.nvim_open_win(buf, false, {
    split = "right",
    win = -1,
    width = 1,
    noautocmd = true,
  })

  local wo = vim.wo[win]

  wo.winfixwidth = true
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.statuscolumn = ""
  wo.cursorline = false
  wo.list = false
  wo.wrap = false
  wo.winhighlight = "Normal:ClowkMargin,NormalNC:ClowkMargin"

  fill(win)
  hide_seam(win)
end

local function set_hl()
  -- No background at all, and that is the whole point.
  --
  -- Neovim paints `Normal` with the terminal's DEFAULT background rather than
  -- with a colour of its own, and the default background is the one thing
  -- `background-opacity` in setup/ghostty/config acts on. A cell given an
  -- explicit `bg` opts out of that: it comes out opaque in the middle of a
  -- translucent window, which at the very edge of the screen reads as a strip
  -- of something stuck to the side.
  --
  -- Both colours were tried there and both were wrong for the same reason --
  -- the panel's made a second thin panel, the gap's made a dark band. Leaving
  -- the background alone makes the column what it should have been from the
  -- start: a line, and nothing else.
  vim.api.nvim_set_hl(0, "ClowkMargin", {
    fg = vim.api.nvim_get_hl(0, { name = "ClowkFrame", link = false }).fg,
  })

  -- The separator next to the border, with the gap's background taken off it.
  vim.api.nvim_set_hl(0, "ClowkSeam", {
    fg = vim.api.nvim_get_hl(0, { name = "WinSeparator", link = false }).fg,
  })
end

function M.setup()
  set_hl()

  local group = vim.api.nvim_create_augroup("clowk_margin", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    desc = "Keep the border colour through a colorscheme change",
    callback = set_hl,
  })

  vim.api.nvim_create_autocmd({ "VimEnter", "WinNew", "WinClosed", "TabEnter", "VimResized", "WinResized" }, {
    group = group,
    desc = "Keep the right border on screen and the right height",
    callback = function()
      vim.schedule(M.ensure)
    end,
  })

  -- Nobody edits a border. `wincmd p` goes back where the cursor came from,
  -- which is what `<C-w>l` into it should have done in the first place.
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    desc = "Bounce out of the border",
    callback = function()
      if vim.api.nvim_get_current_win() == M.win() then
        vim.cmd("wincmd p")
      end
    end,
  })
end

return M
