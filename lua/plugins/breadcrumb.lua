-- Breadcrumb in the winbar, the way VSCode shows it.
--
-- LazyVim ships no breadcrumb. What it does enable by default is the trouble
-- symbol path in the STATUSLINE at the bottom (lualine_c) -- the symbol you are
-- inside, without the file path. The `editor.navic` extra does not help either:
-- it also writes to the statusline, and only when vim.g.trouble_lualine is
-- false, which is not the default.
--
-- dropbar builds the path from three sources, in order of preference: LSP
-- documentSymbol, treesitter, and the file path. Every segment is clickable and
-- opens a menu to jump around; <leader>cb does the same from the keyboard.
--
-- The symbol part is therefore duplicated between the winbar and the statusline.
-- To keep it only at the top, like VSCode, put this in lua/config/options.lua:
--   vim.g.lazyvim_lualine_trouble = nil
--   vim.g.trouble_lualine = false
return {
  {
    "Bekaboo/dropbar.nvim",
    event = "LazyFile",
    keys = {
      {
        "<leader>cb",
        function()
          require("dropbar.api").pick()
        end,
        desc = "Breadcrumb (pick)",
      },
    },
    opts = {},
  },
}
