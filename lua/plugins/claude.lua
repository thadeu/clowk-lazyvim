-- cmd+option+b: a right-hand sidebar running Claude Code in the project root.
--
-- No plugin needed -- this is Snacks' terminal, opened as a vertical split on
-- the right instead of the bottom one cmd+j gives you.
--
-- The key is declared here rather than in lua/config/keymaps.lua because it has
-- to load snacks.nvim to run, and a `keys` spec is what makes lazy.nvim do that
-- on the first press instead of at startup.

return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<M-B>",
        function()
          if vim.fn.executable("claude") == 0 then
            vim.notify("claude is not on PATH", vim.log.levels.ERROR, { title = "Claude Code" })

            return
          end

          -- LazyVim.root() is the root of the file you are in, not Neovim's
          -- cwd, so the sidebar follows you across projects in one session.
          --
          -- Snacks keys its terminals by command AND cwd, so each project gets
          -- its own Claude, and toggling returns to the one already running
          -- rather than starting a second.
          Snacks.terminal.toggle("claude", {
            cwd = LazyVim.root(),
            win = {
              position = "right",
              -- A fraction is a share of the editor width; an integer would be
              -- a fixed number of columns instead. Tune this line to taste.
              width = 0.23,
              wo = { winbar = "" },
            },
          })
        end,
        mode = { "n", "i", "t" },
        desc = "Claude Code (sidebar)",
      },
    },
  },
}
