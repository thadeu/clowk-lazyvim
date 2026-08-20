-- The editor drawn as a panel: a rounded frame around the window, the way
-- lazygit frames each of its boxes.
--
-- lazygit can do it because it owns every cell of the screen. Neovim does not
-- hand a window that kind of canvas, and the box it CAN draw by itself -- the
-- four-sided border of a floating window -- is out of reach here: a float
-- cannot be split (`Cannot split a floating window`), so the editor, which is
-- nothing but splits, can never be one.
--
-- What a window does give away is three of its four edges, and they are drawn
-- here with the decorations Neovim already renders around the text:
--
--   top     `winbar`, one row above the text. The breadcrumb rides INSIDE it.
--   left    `statuscolumn`, the gutter the line numbers live in.
--   bottom  `statusline`, which is lualine -- see lua/plugins/lualine.lua for
--           the two corner pieces.
--
-- The fourth edge is not a decision, it is a wall. A window can reserve a cell
-- on its LEFT (that is what `statuscolumn` is) and has nothing of the kind on
-- its right: the only column there is the separator, and the separator belongs
-- to the layout, not to the window -- it sits one cell further right than the
-- corner the winbar can reach, so the corners would never meet the line. The
-- dark gap from lua/config/panels.lua closes that side instead.
--
-- The horizontal runs cost nothing to draw, and that is the one piece of luck
-- here: `fillchars` has `wbr` for the winbar and `stl`/`stlnc` for the
-- statusline, which is the character each of them pads itself with. Set them
-- to `─` and a `%=` in the middle of the line stretches the border to the exact
-- width of the window -- no arithmetic, and nothing to recompute on a resize.
--
-- dropbar needs no persuading to share the winbar with the frame. Its own
-- `enable` refuses any window that ALREADY has one (`vim.wo[win].winbar ~= ''`
-- in dropbar/configs.lua), so setting the frame first is enough to make it
-- stand down -- while `v:lua.dropbar()` inside the frame still builds the bar
-- on demand, clicks and menus included.

local M = {}

--- What dropbar puts in a bar, through a wrapper of ours.
---
--- It is drawn in the STATUSLINE now (lua/plugins/lualine.lua), not up here:
--- the winbar is one row and the tabs took it. A statusline evaluates click
--- regions the same way a winbar does, so the path stays clickable.
---
--- Calling `v:lua.dropbar()` from the frame directly is what the plugin itself
--- writes, and it throws where the frame has to live: dropbar is lazy-loaded on
--- the first FILE, and `nvim .` opens on a directory -- a dashboard and a tree,
--- no file anywhere. The winbar drew, the call failed, and every redraw of the
--- picker raised `attempt to call global 'dropbar'`.
---
--- The window is already the right one: Neovim evaluates a `%{}` with the
--- window being drawn as the current one, which is where dropbar reads its
--- buffer and window from.
function M.breadcrumb()
  if _G.dropbar == nil then
    return ""
  end

  local ok, str = pcall(_G.dropbar)

  if not ok then
    return ""
  end

  -- Lined up with the line NUMBERS, so the gutter and the path share a left
  -- edge.
  --
  -- Where the numbers begin is not a constant: they are right-aligned in their
  -- field, so a two-digit line starts one column further right than a
  -- three-digit one, and the field itself moves whenever a sign column appears.
  -- Rather than guess at any of that, the statuscolumn is RENDERED and the
  -- first digit found in it -- `nvim_eval_statusline` draws it for whichever
  -- line is asked for, and the width of everything before that digit is the
  -- column to start on.
  --
  -- The line asked for is the one at the TOP of the window, so the path lines
  -- up with the numbers actually on screen. The widest number in the file was
  -- the first answer and it is subtly wrong: the numbers are right-aligned, so
  -- in a 200 line file viewed at line 20 the widest starts a column further
  -- left than anything visible, and the path sat one cell off. This moves only
  -- when the top number gains a digit.
  --
  -- Minus one for the edge, which this row draws itself. A window with no
  -- numbers at all -- the dashboard -- has no digit to find, and falls back to
  -- the offset of the text.
  local win = vim.api.nvim_get_current_win()
  local top = vim.fn.line("w0", win)
  local gutter = vim.api.nvim_eval_statusline(vim.wo[win].statuscolumn, {
    winid = win,
    use_statuscol_lnum = top,
  }).str
  local digit = gutter:find("%d")
  local at = digit and vim.fn.strdisplaywidth(gutter:sub(1, digit - 1)) or vim.fn.getwininfo(win)[1].textoff

  return (" "):rep(math.max(at - 1, 0)) .. str
end

--- The top edge, which is also the row of buffer tabs: `nvim_bufferline()` is
--- the same string bufferline would have put in the tabline, and
--- lua/plugins/bufferline.lua takes the tabline away from it.
---
--- The corner is ours; everything after it is bufferline's, padding included --
--- it measures against the screen and pads to it, so there is no room for a
--- `─╮` on the other end and no `%=` to put one at. The right side of these
--- windows is the wall described above anyway: the corner can be drawn, the
--- line under it cannot, and a corner with nothing hanging off it reads as a
--- box that failed. The tab strip runs to the edge and the panel ends where
--- the screen does.
--- The top edge of a panel is NOT here any more: it is the tabline, which
--- lua/plugins/bufferline.lua composes as the lid of every panel with the
--- buffer tabs sitting inside the editor's. What a window draws for itself is
--- the row under that lid -- the breadcrumb -- and the left edge in front of
--- it.
---
--- Two rows of chrome is one more than a window has: `winbar` is a single row,
--- and so is `statusline`. The tabline is the only other line available, and
--- being screen-wide is exactly what makes it able to draw a lid over each
--- column at once.
--- `%<` right after the edge is the truncation POINT: a path long enough to
--- overflow a narrow split is cut from there, losing the leftmost segments and
--- keeping the edge. Without it Neovim cuts at the front of the line, and the
--- front of the line is the frame -- the split came out with a `<` where its
--- left edge belongs.
M.winbar = "%#ClowkFrame#│%*%<%{%v:lua.require'config.frame'.breadcrumb()%}"

--- The row under the lid, for the panels that have no breadcrumb to put there
--- -- a terminal, a find and replace. The name goes where the path would be.
---@param title string
function M.top(title)
  return "%#ClowkFrame#│%* " .. title
end

--- The panel docked on the RIGHT of the editor, if there is one: its width and
--- what to call it. lua/plugins/bufferline.lua draws its lid in the tabline
--- along with the others, and the tabline knows nothing about who is docked
--- where.
---
--- Recognised by the command it runs rather than by its filetype: every snacks
--- terminal shares one filetype, and only this one is a panel.
---@return integer?, string?
function M.right_panel()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local term = vim.b[buf].snacks_terminal

    if term and term.cmd == "claude" then
      return vim.api.nvim_win_get_width(win), "claude"
    end
  end
end

--- The left edge for a panel with no gutter of its own.
M.edge = "%#ClowkFrame#│%*"

--- The left edge, in front of whatever the gutter was already showing.
---
--- Wrapped in a pcall because this runs on every redraw of every window, snacks
--- included, and its statuscolumn asks the window it is drawn for about its
--- buffer -- a question that has no answer while a floating window is being
--- torn down. A frame with no numbers beats an error on every keystroke.
function M.statuscolumn()
  local ok, col = pcall(function()
    return require("snacks.statuscolumn").get()
  end)

  return M.edge .. (ok and col or "")
end

--- Buffers that are not files and still get the frame: the dashboard is what
--- the editor area IS on `nvim .`, so leaving it bare made the whole start
--- screen look like the one panel nobody had finished.
local EXTRA = { snacks_dashboard = true }

--- Windows this module puts a top edge on by itself: the ones holding a file,
--- plus EXTRA.
---
--- A float draws its own border, and any other buffer that is not a file --
--- quickfix, help, a terminal, the prompt of a picker -- belongs to whatever
--- opened it. Those panels ask for M.top() with a name of their own instead,
--- the way lua/plugins/claude.lua and the search panel do; framing them from
--- here would write the breadcrumb over the title they chose.
local function framed(win)
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return false
  end

  local buf = vim.api.nvim_win_get_buf(win)

  return vim.bo[buf].buftype == "" or EXTRA[vim.bo[buf].filetype] or false
end

local function set_hl()
  local function hl(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false })
  end

  local edge = hl("FloatBorder").fg

  -- No `bg`: the frame is drawn inside windows that do not share one -- the
  -- editor has `Normal`, the sidebar has ClowkSidebarPanel -- and leaving it
  -- out lets each cell keep the background of the window it lands in.
  vim.api.nvim_set_hl(0, "ClowkFrame", { fg = edge })

  -- The lids are the exception, and they have to say their background out
  -- loud: they are drawn in the TABLINE, one line that runs over every column,
  -- so nothing underneath is there to inherit from. Three colours in a row --
  -- the sidebar's panel, the dark gap, the editor -- on one line.
  vim.api.nvim_set_hl(0, "ClowkLid", { fg = edge, bg = hl("NormalFloat").bg })
  vim.api.nvim_set_hl(0, "ClowkLidEditor", { fg = edge, bg = hl("Normal").bg })
  vim.api.nvim_set_hl(0, "ClowkLidLogo", { fg = hl("Title").fg, bg = hl("NormalFloat").bg, bold = true })
  vim.api.nvim_set_hl(0, "ClowkLidGap", { fg = hl("WinSeparator").bg, bg = hl("WinSeparator").bg })
end

function M.setup()
  -- One statusline per window, because the bottom edge belongs to the panel
  -- and not to the screen. LazyVim's lualine reads this at startup
  -- (`globalstatus = vim.o.laststatus == 3`) and follows.
  --
  -- The winbar has a `wbr` fillchar of its own and it is deliberately left
  -- alone: this row is the breadcrumb, not an edge, and a rule running out of
  -- the end of a path reads as a second lid one row under the first.
  vim.o.laststatus = 2

  -- `%!` and not `%{%...%}`: snacks' gutter right-aligns the number with a
  -- `%=`, and an alignment item inside a re-evaluated expression is dropped --
  -- the frame drew, the numbers did not. With `%!` the whole option IS the
  -- expression, which is how LazyVim hands snacks the same string.
  vim.o.statuscolumn = "%!v:lua.require'config.frame'.statuscolumn()"

  set_hl()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("clowk_frame_hl", { clear = true }),
    desc = "Keep the frame colour through a colorscheme change",
    callback = set_hl,
  })

  -- The dashboard hides both bars while it is up -- `vim.o.showtabline,
  -- vim.o.laststatus = 0, 0` in snacks/dashboard.lua -- which takes the name
  -- off the tabline and the bottom edge off the panel, on the one screen that
  -- is nothing but panels. Put back after it opens.
  --
  -- Its own restore on close is written as "only if still 0", so setting these
  -- back here does not fight it: it finds them at 2 and leaves them alone.
  vim.api.nvim_create_autocmd("User", {
    pattern = "SnacksDashboardOpened",
    group = vim.api.nvim_create_augroup("clowk_frame_dashboard", { clear = true }),
    desc = "Keep the tabline and the statusline on the start screen",
    callback = function()
      vim.o.showtabline = 2
      vim.o.laststatus = 2
    end,
  })

  -- The top edge is set per WINDOW, never as the global option, and that is
  -- not a preference. `winbar` is global-local, and for a string option of
  -- that kind an empty local value does not mean "no winbar" -- it means "use
  -- the global one". Every window that turns its winbar off, snacks' own among
  -- them, would have inherited the frame and worn a lid it never asked for.
  --
  -- dropbar loses nothing by this. It refuses any window that already has a
  -- winbar, so whichever of the two runs first, what stays on screen is the
  -- frame with the breadcrumb inside it.
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew", "WinEnter", "TermOpen", "FileType" }, {
    group = vim.api.nvim_create_augroup("clowk_frame_winbar", { clear = true }),
    desc = "A top edge on the windows that are panels",
    callback = function()
      vim.schedule(function()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.api.nvim_win_is_valid(win) and framed(win) then
            vim.wo[win][0].winbar = M.winbar

            -- The left edge rides on the gutter, and a window can be told to
            -- have none: the dashboard turns its `statuscolumn` off, so the
            -- box came out with a top, a bottom, two corners and no left side
            -- between them. Empty means nothing is drawing that column, so the
            -- edge goes there alone.
            if vim.wo[win][0].statuscolumn == "" then
              vim.wo[win][0].statuscolumn = M.edge
            end
          end
        end
      end)
    end,
  })
end

return M
