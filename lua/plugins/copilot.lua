-- AI autocomplete: VSCode's grey ghost text, accepted with <Tab>.
--
-- The plugin and its wiring are LazyVim's `ai.copilot` extra, imported in
-- lua/config/lazy.lua. Everything that makes it behave like VSCode rather than
-- like a completion source is `vim.g.ai_cmp = false` in lua/config/options.lua.
-- This file is only what is left over: first-run instructions, and a switch.
--
-- Why Copilot here and Claude everywhere else in this config
-- ---------------------------------------------------------
-- As-you-type completion and "write me a commit message" look like one feature
-- and are not. The first fires on every pause in typing and is only useful
-- under ~300ms, which rules out a general-purpose model: Claude is not trained
-- for fill-in-the-middle, and reaching it needs an ANTHROPIC_API_KEY billed per
-- token, separate from the Claude Code subscription -- so every keystroke would
-- cost money to answer slower. Copilot's model is small, purpose-built for this
-- one job, and free up to 2000 completions a month.
--
-- Claude keeps the work where a good answer beats a fast one: the commit
-- messages (lua/plugins/claude-commit.lua) and the sidebar (lua/plugins/claude.lua).
--
-- First run
-- ---------
-- `:Copilot auth` opens a browser and a device code; `:Copilot status` says
-- whether it took. The extra runs the auth command once on install, so this is
-- usually already done by the time you read it.
--
-- Node is a real dependency here (the language server behind Copilot runs on
-- it), which this config already installs for the TypeScript stack.

return {
  {
    "zbirenbaum/copilot.lua",
    opts = {
      -- Copilot's own defaults switch it off in commit buffers, and that is
      -- left alone deliberately -- <leader>gm is Claude's job there, and two
      -- engines writing into the same buffer would fight. LazyVim re-enables
      -- markdown and help on top, which this config wants: the README is the
      -- largest file in the repo.
      --
      -- The suggestion block is spelled out rather than inherited so the keys
      -- are greppable from here. `accept = false` is not a typo and not a
      -- disabled feature: <Tab> is bound on the blink.cmp side instead, so that
      -- one key can mean "take the suggestion" when there is one and stay an
      -- ordinary Tab when there is not. Letting copilot.lua also grab <Tab>
      -- would shadow that.
      suggestion = {
        keymap = {
          accept = false,
          -- Cycle through alternatives without accepting, the same pair VSCode
          -- uses. Ghostty sends the left option key as Alt, so these arrive as
          -- option+] and option+[.
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>uP", function() require("copilot.command").toggle() end, desc = "Toggle Copilot (suggestions)" },
    },
  },

  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>uP", icon = { icon = " ", color = "cyan" } },
      },
    },
  },
}
