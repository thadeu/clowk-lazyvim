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
    opts = function(_, opts)
      -- Names only, no icons.
      --
      -- dropbar puts three kinds of icon in the bar: one for the file, one for
      -- a directory, and one per LSP symbol kind -- the `{}` in front of every
      -- key of a yaml file. On a path five segments long that is five glyphs
      -- competing with the five words that carry the meaning.
      --
      -- `icons.enable = false` is dropbar's own switch for this and is not
      -- used: it blanks `icons.ui` as well, which is where the separator lives,
      -- and it does it by metatable -- something `vim.tbl_deep_extend` drops on
      -- the way through, leaving the bar with nil where it wants a string. The
      -- kinds are spelled empty one by one instead, from dropbar's own list, so
      -- a kind it learns later comes out empty too rather than missing.
      local symbols = require("dropbar.configs").opts.icons.kinds.symbols
      local blank = {}

      for kind in pairs(symbols) do
        blank[kind] = ""
      end

      return vim.tbl_deep_extend("force", opts or {}, {
        -- No padding on the left: lua/config/frame.lua puts its own there, as
        -- many columns as the gutter of that window costs, so the path starts
        -- where the code starts. Two hands on the same indent would fight.
        bar = { padding = { left = 0, right = 1 } },
        icons = {
          kinds = {
            dir_icon = "",
            file_icon = "",
            symbols = blank,
          },
          ui = {
            bar = {
              -- Air on BOTH sides of the chevron. dropbar ships it with a
              -- space after and none before, so a segment ran straight into the
              -- separator behind it -- `compose.build.yml services`. VSCode
              -- gives the chevron a column of its own, and that is the whole
              -- difference between a path you read and one you decode.
              --
              -- A TEXT chevron, and not the Nerd Font one dropbar ships
              -- (U+F460). A Nerd Font glyph is an icon as far as the terminal
              -- is concerned, and a terminal fits icons to the cell -- Ghostty
              -- does, iTerm2 does not, which is why the same file icons looked
              -- inflated in one and right in the other. `›` is ordinary text
              -- and is drawn as text, in every terminal.
              separator = " \u{203a} ",
            },
          },
        },
      })
    end,
  },
}
