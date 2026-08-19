-- Show hidden and git-ignored files everywhere.
--
-- The snacks picker (which is what LazyVim's explorer and file finder are)
-- defaults to `hidden = false, ignored = false` on every source, so `.env`,
-- `.voodu`, `node_modules` and `dist` are invisible until `H` / `I` is pressed
-- inside the picker. This flips both on by default.
--
-- `H` and `I` still toggle them back off per-session.

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        -- The sidebar tree. `exclude` is needed here because, unlike `files`,
        -- the explorer finder has no built-in .git filter -- with hidden = true
        -- the whole .git directory would show up at the top of every repo.
        --
        -- The layout and the icon row come from lua/config/sidebar.lua, and
        -- they are set HERE rather than on the call that opens the panel: the
        -- explorer also opens by itself when Neovim starts on a directory
        -- (`nvim .`), and that door is snacks', not ours.
        explorer = vim.tbl_deep_extend("force", {
          hidden = true,
          ignored = true,
          exclude = { ".git" },
        }, require("config.sidebar").explorer_source()),
        -- File finder (<leader>ff, <leader><space>, cmd+p). fd/rg already drop
        -- .git themselves.
        files = { hidden = true, ignored = true },
        -- Live grep (<leader>/, <leader>sg).
        grep = { hidden = true, ignored = true },
      },
    },
  },
}
