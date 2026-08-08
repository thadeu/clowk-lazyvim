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
        explorer = {
          hidden = true,
          ignored = true,
          exclude = { ".git" },
        },
        -- File finder (<leader>ff, <leader><space>, cmd+p). fd/rg already drop
        -- .git themselves.
        files = { hidden = true, ignored = true },
        -- Live grep (<leader>/, <leader>sg).
        grep = { hidden = true, ignored = true },
      },
    },
  },
}
