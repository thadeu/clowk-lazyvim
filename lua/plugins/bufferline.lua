-- The buffer tabs, drawn INSIDE the editor panel.
--
-- They used to be what they are everywhere else: `vim.o.tabline`, one line of
-- the screen above everything, with an `offsets` entry keeping them clear of
-- the sidebar. The panel frame (lua/config/frame.lua) made that read wrong --
-- the tabs of a panel were floating above its lid instead of sitting on it.
--
-- So the tabline is off and the same string goes into the WINBAR of every
-- window that holds a file, which is the panel's top edge. What that buys, and
-- what it costs:
--
--   + the tabs are inside the box, which is where a tab belongs
--   + every split gets its own row of tabs, the way an editor with two panes
--     open shows two sets of tabs
--   + the screen gets its top line back
--   - bufferline measures against `vim.o.columns`, not against the window it is
--     drawn in. `custom_areas` below is what squares that up
--
-- `auto_toggle_bufferline = false` is what keeps the tabline down: without it
-- bufferline sets `showtabline` back to 2 on every buffer it sees.

--- The colour of a highlight group, as the `#rrggbb` string bufferline wants.
local function colour(name, attr)
  local hl = vim.api.nvim_get_hl(0, { name = name, link = false })

  return hl[attr] and ("#%06x"):format(hl[attr]) or nil
end

--- Every group that has to sit flat on the strip, and every one that belongs to
--- the tab you are on. bufferline builds each of them by shading `Normal`, and
--- on a background this dark the shades come out within a point or two of each
--- other -- the tabs were there, and nothing told you which one was open.
---
--- Only `bg` is given: the table is deep-merged over what bufferline derived,
--- so every foreground it worked out survives.
local FLAT = {
  "fill",
  "background",
  "buffer_visible",
  "tab",
  "tab_close",
  "tab_separator",
  "close_button",
  "close_button_visible",
  "numbers",
  "numbers_visible",
  "diagnostic",
  "diagnostic_visible",
  "hint",
  "hint_visible",
  "hint_diagnostic",
  "hint_diagnostic_visible",
  "info",
  "info_visible",
  "info_diagnostic",
  "info_diagnostic_visible",
  "warning",
  "warning_visible",
  "warning_diagnostic",
  "warning_diagnostic_visible",
  "error",
  "error_visible",
  "error_diagnostic",
  "error_diagnostic_visible",
  "modified",
  "modified_visible",
  "duplicate",
  "duplicate_visible",
  "indicator_visible",
  "pick",
  "pick_visible",
  "offset_separator",
  "trunc_marker",
}

local CHIP = {
  "buffer_selected",
  "tab_selected",
  "tab_separator_selected",
  "close_button_selected",
  "numbers_selected",
  "diagnostic_selected",
  "hint_selected",
  "hint_diagnostic_selected",
  "info_selected",
  "info_diagnostic_selected",
  "warning_selected",
  "warning_diagnostic_selected",
  "error_selected",
  "error_diagnostic_selected",
  "modified_selected",
  "duplicate_selected",
  "indicator_selected",
  "pick_selected",
}

return {
  "akinsho/bufferline.nvim",
  opts = function(_, opts)
    opts.options = opts.options or {}

    -- The tabline is always up, because it is not a tabline any more: it is the
    -- row of LIDS, and a panel with no lid is a panel with a hole in it.
    opts.options.always_show_bufferline = true

    -- A tab is a chip: a block of its own colour, with a column of air on each
    -- side of it.
    --
    -- The air is the SEPARATOR, and a separator on both ends of a tab is
    -- reached only through the four style NAMES bufferline knows (`is_slant` in
    -- bufferline/ui.lua). The characters, though, are a plain data table, so
    -- `slant` keeps its logic and gets two spaces instead of its diagonals.
    --
    -- The round powerline caps (U+E0B6, U+E0B4) were the first answer, and they
    -- are the right shape: a cap drawn in the tab's own colour ends the block
    -- in a curve. In this terminal they are also the WRONG size --
    -- `adjust-icon-height = 150%` in setup/ghostty/config scales Nerd Font
    -- glyphs so the sidebar icons are legible, and those caps live in the same
    -- private-use range. They came out as half circles a cell and a half tall,
    -- with a hole between the cap and the text. A terminal cell cannot do a
    -- small radius anyway: the choice is a full half-circle or a straight edge,
    -- and the straight edge is the one that reads as a tab.
    require("bufferline.constants").sep_chars.slant = { " ", " " }

    opts.options.separator_style = "slant"

    -- The lids, drawn around the tabs.
    --
    -- bufferline assembles its line in this order (`ui.lua`):
    --
    --   offsets.left · custom_areas.left · TABS · custom_areas.right · offsets.right
    --
    -- so a custom area is a way to put something immediately before the first
    -- tab and immediately after the last one, and what it measures comes off
    -- the width bufferline has to fill. That is the whole mechanism: the left
    -- area draws the sidebar's lid, the gap column and the editor's corner; the
    -- right one draws the lid of the Claude panel; and the tabs land in between,
    -- sized to what is left, which is the editor.
    --
    -- Each item carries its own highlight, and the lids have to say their
    -- background out loud: this one line runs over three panels with three
    -- backgrounds, and there is nothing underneath a tabline to inherit from.
    opts.options.custom_areas = {
      left = function()
        local sidebar = require("config.sidebar")
        local width = sidebar.column_width()
        local out = {}

        if width then
          local lead = "╭─ "
          local fill = math.max(width - vim.fn.strdisplaywidth(lead .. sidebar.logo .. " ") - 1, 0)

          out[#out + 1] = { text = lead, link = "ClowkLid" }
          out[#out + 1] = { text = sidebar.logo, link = "ClowkLidLogo" }
          out[#out + 1] = { text = " " .. ("─"):rep(fill) .. "╮", link = "ClowkLid" }
          out[#out + 1] = { text = " ", link = "ClowkLidGap" }
        end

        out[#out + 1] = { text = "╭─", link = "ClowkLidEditor" }

        return out
      end,

      right = function()
        local out = {}
        local width, title = require("config.frame").right_panel()

        if width then
          -- The gap column belongs to the layout, not to the panel, so it is
          -- drawn here but kept OUT of the panel's own width.
          local lead = "╭─ " .. title .. " "
          local fill = math.max(width - vim.fn.strdisplaywidth(lead), 0)

          out[#out + 1] = { text = " ", link = "ClowkLidGap" }
          out[#out + 1] = { text = lead .. ("─"):rep(fill), link = "ClowkLidEditor" }
        end

        -- The last two cells of the screen when the right border is up: the
        -- gap, and the corner over the column that border occupies.
        if require("config.margin").win() then
          out[#out + 1] = { text = " ", link = "ClowkLidGap" }
          out[#out + 1] = { text = "╮", link = "ClowkMargin" }
        end

        return out
      end,
    }

    -- No bar down the side of the open tab: the background says which one it
    -- is, exactly as it does in VSCode.
    opts.options.indicator = { style = "none" }

    -- The close button only on the tab you are on, and on the one under the
    -- mouse. That is bufferline's `hover`, and it needs Neovim to report the
    -- mouse moving at all.
    opts.options.hover = { enabled = true, delay = 0, reveal = { "close" } }
    vim.o.mousemoveevent = true

    -- Our colours, and not the colourscheme's.
    --
    -- bufferline writes every group with `default = true`, which in Neovim
    -- means "only if it does not exist yet" -- so the three BufferLine groups
    -- colors/clowk-night.lua happens to define (Fill, BufferSelected,
    -- IndicatorSelected) won, and the tab you are on came out with no
    -- background at all. `themable = false` is the switch bufferline offers for
    -- exactly that, and the fg those groups carried is spelled out below.
    opts.options.themable = false

    -- The strip the chips sit on IS the panel now, so it takes the editor's
    -- own background rather than the dark gap between panels.
    local fill, chip = colour("Normal", "bg"), colour("CursorLine", "bg")
    local hl = {}

    for _, name in ipairs(FLAT) do
      hl[name] = { bg = fill }
    end

    for _, name in ipairs(CHIP) do
      hl[name] = { bg = chip }
    end

    -- The air on either side of a tab belongs to the strip, whichever tab it
    -- sits next to.
    hl.separator = { fg = fill, bg = fill }
    hl.separator_visible = { fg = fill, bg = fill }
    hl.separator_selected = { fg = fill, bg = fill }
    hl.buffer_selected = { bg = chip, fg = colour("Normal", "fg"), bold = true, italic = false }

    opts.highlights = vim.tbl_deep_extend("force", opts.highlights or {}, hl)
  end,
}
