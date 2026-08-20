-- The other half of the gap between panels. lua/config/panels.lua is the first
-- half, and says what the gap is and why it is drawn the way it is.
--
-- `fillchars` is a global-LOCAL option: a window that sets its own value stops
-- reading the global one. snacks sets one (`eob: ,lastline:…`) on every window
-- it owns, and the windows on either side of the sidebar and of the Claude
-- panel are snacks windows -- so without this line they were the only splits
-- still drawing a `│` where every other one had already gone quiet.
--
-- It has to be the GLOBAL snacks default and not a per-picker option. A split
-- layout is wrapped by snacks in a box of its own making (`snacks_layout_box`
-- in layout.lua), that box is the window that actually touches the editor, and
-- it is built from a fixed set of keys -- a `wo` passed with the layout stays
-- on the inner box and never reaches it. `Snacks.config.win` does reach it,
-- because every snacks window resolves against it.
return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.win = opts.win or {}
      opts.win.wo = vim.tbl_extend("force", opts.win.wo or {}, {
        fillchars = require("config.panels").fillchars(),
      })
    end,
  },
}
