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

          -- Snacks identifies a terminal by cmd + cwd + count, so the cwd has
          -- to come out the same on every press or the toggle stops finding
          -- the one already running and opens a second.
          --
          -- LazyVim.root() alone does not: it is the root of the CURRENT
          -- buffer, and pressing this from inside the sidebar means asking a
          -- terminal buffer -- which has no file, so it answers with something
          -- else. So when we are already in a Claude sidebar, reuse the cwd it
          -- was opened with, which snacks records on the buffer.
          --
          -- From a file buffer it is still LazyVim.root(), so the sidebar
          -- follows you across projects and each one gets its own Claude.
          local this = vim.b[vim.api.nvim_get_current_buf()].snacks_terminal
          local cwd = this and this.cmd == "claude" and this.cwd or LazyVim.root()

          Snacks.terminal.toggle("claude", {
            cwd = cwd,
            -- Pinned, because snacks defaults this to vim.v.count1 -- a stray
            -- count typed before the key would otherwise be a different id.
            count = 1,
            win = {
              position = "right",
              -- The panel frame, minus the gutter this terminal has no use
              -- for. The lid is drawn in the tabline with the others
              -- (lua/plugins/bufferline.lua); this is the row under it, and a
              -- bare line down the left. lualine closes the bottom, and the
              -- right side is the screen -- see lua/config/frame.lua for why
              -- there is no fourth.
              wo = {
                winbar = require("config.frame").top(" claude "),
                statuscolumn = require("config.frame").edge,
              },
              -- A fraction is a share of the editor width; an integer would be
              -- a fixed number of columns instead. Tune this line to taste.
              width = 0.23,
            },
          })
        end,
        mode = { "n", "i", "t" },
        desc = "Claude Code (sidebar)",
      },
    },
  },
}
