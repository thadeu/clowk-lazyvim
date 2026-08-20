-- The dark gap between the panels: VSCode's editor, sidebar and secondary
-- sidebar, each reading as a card of its own.
--
-- A terminal cannot round a corner. The smallest thing Neovim can paint is one
-- cell, so a radius is always a glyph, never a curve. The other half of that
-- look does come across, though: the strip of app background between two
-- panels. The column Neovim already draws between two vertical splits is
-- exactly one cell wide, and that column is the gap.
--
-- Two options make it, and WHICH half of each is used is the whole trick:
--
--   * `fillchars` picks the CHARACTER of the column. A space has no glyph, so
--     the cell is nothing but its background.
--   * `WinSeparator` picks the colour, and only its `bg` is taken. The `fg` is
--     still the colour of the horizontal rule between stacked windows -- the
--     one under the icon bar in the sidebar, which lua/config/sidebar.lua
--     deliberately matches with ClowkSidebarDivider. Painting the gap with
--     `fg` would have erased that rule and its twin in one go.
--
-- `fillchars` is a global-LOCAL option, which is the entire reason M.fillchars
-- exists. A window that sets its own value stops reading the global one, and
-- snacks sets one (`eob: ,lastline:…`) on every window it owns. The sidebar IS
-- a snacks window, and the separator between two splits is drawn by the window
-- on the LEFT of it -- so the sidebar was the one window still drawing `│`
-- while every other split had already lost it. Those windows are handed
-- M.fillchars instead; lua/config/sidebar.lua is where that happens.
--
-- The colour is derived, not written down. colors/clowk-night.lua is generated
-- by clowk-terminal and is overwritten whole on every regeneration, so nothing
-- of ours may live in it. The gap is the darker of the two backgrounds a panel
-- can have, darkened again. DEPTH is the knob: lower is darker, and 1.0 makes
-- the gap disappear into the panel.

local M = {}

local DEPTH = 0.45

--- The junction characters belong to the gap column as much as `vert` does: a
--- `┤` where the horizontal rule meets it would be a notch in the strip.
local GAP = {
  vert = " ",
  vertleft = " ",
  vertright = " ",
  verthoriz = " ",
  horizup = " ",
  horizdown = " ",
}

--- What a window has to be told when it sets `fillchars` for itself: the two
--- snacks defaults it would otherwise lose, plus everything the global value
--- carries -- the gap here, and the fill of the frame from
--- lua/config/frame.lua.
---
--- Read at the moment a window is built rather than baked in at startup, so a
--- character added to the global one later still reaches those windows. Every
--- caller runs long after both setups.
function M.fillchars()
  return "eob: ,lastline:…," .. vim.o.fillchars
end

--- A colour is one 24-bit number here, not a string -- that is what
--- nvim_get_hl answers and what nvim_set_hl takes.
local function channels(rgb)
  return math.floor(rgb / 0x10000) % 0x100, math.floor(rgb / 0x100) % 0x100, rgb % 0x100
end

local function darker_of(a, b)
  local ar, ag, ab = channels(a)
  local br, bg, bb = channels(b)

  return ar + ag + ab <= br + bg + bb and a or b
end

local function darken(rgb)
  local r, g, b = channels(rgb)

  return math.floor(r * DEPTH) * 0x10000 + math.floor(g * DEPTH) * 0x100 + math.floor(b * DEPTH)
end

local function set_hl()
  local function bg(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false }).bg or 0
  end

  -- The two backgrounds a panel can have: the editor's, and the one snacks
  -- gives its own windows. The gap has to be darker than both of them.
  local sep = vim.api.nvim_get_hl(0, { name = "WinSeparator", link = false })

  vim.api.nvim_set_hl(0, "WinSeparator", {
    fg = sep.fg,
    bg = darken(darker_of(bg("Normal"), bg("NormalFloat"))),
  })
end

function M.setup()
  vim.opt.fillchars:append(GAP)

  set_hl()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("clowk_panels_hl", { clear = true }),
    desc = "Keep the gap between panels through a colorscheme change",
    callback = set_hl,
  })
end

return M
