-- The bottom edge of every panel frame.
--
-- lua/config/frame.lua draws the other edges and says why a window can only
-- give away three of them. This is the fourth line of the box, and it is
-- lualine's own line: `laststatus` is 2, so each window has one, and each one
-- ends its panel.
--
-- The corners are components rather than a string glued around the statusline:
-- first in `lualine_a`, last in `lualine_z`, which is where the line starts and
-- ends no matter what LazyVim puts between them. `color` names a highlight
-- group so they follow the colorscheme, and `padding = 0` keeps them tight --
-- a corner with a space beside it is a corner that misses its line.
--
-- Between the corners the editor's statusline keeps its own content and its
-- own background -- a footer inside the box, the way lazygit's bottom bar sits
-- inside its frame. There is no rule drawn through it on purpose: see `rule`
-- below for the colour that cannot be set.
--
-- The panels that are not the editor get an EXTENSION instead of the ordinary
-- sections. lualine would otherwise write the editor's status into them --
-- `[No Name] [-] 1:1` under a file tree -- and the row is not a status there,
-- it is the bottom of the box.
local function corner(char)
  return {
    function()
      return char
    end,
    color = "ClowkFrame",
    padding = 0,
    -- Both sides spelled out. A bare `separator = ""` still let lualine draw
    -- the powerline wedge of the section next door, which landed between the
    -- rule and the corner.
    separator = { left = "", right = "" },
  }
end

--- The panels that are not the editor draw their whole bottom edge here, as
--- one component with the width measured rather than as two corners with the
--- statusline padding between them.
---
--- The padding was the first attempt and it cannot be coloured. lualine emits
--- the highlight of the MIDDLE section immediately before its `%=`
--- (`format_highlight('c') .. '%=' .. section_data`, hardcoded in
--- lualine.lua), so the run of `─` came out in the colour of the file path --
--- near white, and a bright line under every panel.
---
--- The window is the one lualine is drawing for: it evaluates each statusline
--- inside `nvim_win_call`, so window 0 is that window and not the current one.
---@param closed boolean whether this window has a right edge to meet
local function rule(closed)
  return function()
    local width = vim.api.nvim_win_get_width(0)

    if closed then
      return "╰" .. ("─"):rep(math.max(width - 2, 0)) .. "╯"
    end

    -- No corner: the right side of this window is the wall described in
    -- lua/config/frame.lua, and a `╯` with no line above it reads as a box
    -- that failed rather than as a frame.
    return "╰" .. ("─"):rep(math.max(width - 1, 0))
  end
end

--- The row between the icon bar and the panel under it, which is the
--- statusline of the bar's window.
---
--- It is neither a status nor an edge: it is the blank row that separates the
--- label from the tree, with the two columns of the box carrying on through
--- it. That row exists either way -- every window has a statusline now -- so
--- the choice was to draw the box through it or to let it cut the sidebar in
--- half. It is also the only row available there, the panel below being a
--- different window, which is what makes the air above and below the label
--- come out even.
local function seam()
  local width = vim.api.nvim_win_get_width(0)

  return "│" .. (" "):rep(math.max(width - 2, 0)) .. "│"
end

local function component(fn)
  return {
    fn,
    color = "ClowkFrame",
    padding = 0,
    separator = { left = "", right = "" },
  }
end

--- The bottom edge of a panel that HAS a right side -- the tree, which snacks
--- draws a real border around -- and of one that has not.
local edge = { lualine_a = { component(rule(true)) } }
local edge_open = { lualine_a = { component(rule(false)) } }

--- A line that is nothing but the two sides of the box.
local head = { lualine_a = { component(seam) } }

return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_a, 1, corner("╰─"))

      -- A window that is not the current one keeps its frame: without this the
      -- box of every other split loses its bottom corners the moment you leave
      -- it.
      opts.inactive_sections = opts.inactive_sections or {}
      opts.inactive_sections.lualine_a = opts.inactive_sections.lualine_a or {}

      table.insert(opts.inactive_sections.lualine_a, 1, corner("╰─"))

      opts.extensions = opts.extensions or {}

      -- The left column is ONE box drawn by two windows. The icon bar puts a
      -- lid and two sides on it, its statusline carries those two sides
      -- through the row that separates the label from the tree, the panel
      -- under it carries them on, and the panel's own statusline closes the
      -- bottom.
      table.insert(opts.extensions, {
        filetypes = { "clowk_sidebar" },
        sections = head,
        inactive_sections = head,
      })

      table.insert(opts.extensions, {
        filetypes = { "snacks_layout_box" },
        sections = edge,
        inactive_sections = edge,
      })

      table.insert(opts.extensions, {
        filetypes = { "grug-far", "snacks_dashboard" },
        sections = edge_open,
        inactive_sections = edge_open,
      })

      -- The right border is a window one column wide, so its statusline is one
      -- cell: the corner where the border meets the bottom edge.
      local corner_br = {
        lualine_a = {
          {
            function()
              return "╯"
            end,
            color = "ClowkMargin",
            padding = 0,
            separator = { left = "", right = "" },
          },
        },
      }

      table.insert(opts.extensions, {
        filetypes = { require("config.margin").filetype },
        sections = corner_br,
        inactive_sections = corner_br,
      })

      -- LazyVim turns the statusline off on the start screen. With one per
      -- window that is not a clean line any more, it is a panel with no bottom
      -- edge -- and the row is spoken for either way.
      opts.options.disabled_filetypes = opts.options.disabled_filetypes or {}
      opts.options.disabled_filetypes.statusline = vim.tbl_filter(function(ft)
        return ft ~= "snacks_dashboard"
      end, opts.options.disabled_filetypes.statusline or {})
    end,
  },
}
