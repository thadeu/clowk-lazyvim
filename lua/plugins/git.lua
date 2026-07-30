-- GitLens equivalent.
--
-- Most of it LazyVim already ships and it is not obvious at all -- the full list
-- of pre-existing shortcuts is in the README. This file adds the two things that
-- were genuinely missing: inline blame and a diff browser.

--- Detect the repository's base branch for the "my changes" diff.
---
--- Tries origin/HEAD first, then falls back to the common names. Without this
--- the shortcut would hardcode one branch name and silently break in any repo
--- that uses a different one.
local function base_branch()
  local ref = vim.fn.systemlist({ "git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })
  if vim.v.shell_error == 0 and ref[1] and ref[1] ~= "" then
    return ref[1]
  end
  for _, candidate in ipairs({ "origin/develop", "origin/main", "origin/master" }) do
    vim.fn.system({ "git", "rev-parse", "--verify", "--quiet", candidate })
    if vim.v.shell_error == 0 then
      return candidate
    end
  end
  return "HEAD~1"
end

return {
  -- 1. Inline blame -- GitLens' signature feature.
  --
  -- gitsigns already ships with LazyVim; LazyVim just never enables this
  -- (current_line_blame defaults to false).
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        -- gitsigns defaults to 1000ms, which reads as a freeze. 300ms feels
        -- close to GitLens without slowing navigation down.
        delay = 300,
        ignore_whitespace = true,
      },
      -- gitsigns default: " <author>, <author_time:%R> - <summary> "
      -- %R renders as "3 days ago". The short sha at the end is there to paste
      -- straight into a `git show`.
      current_line_blame_formatter = "  <author> · <author_time:%R> · <summary> · <abbrev_sha>",
    },
  },

  -- 2. Diffview -- the diff and history browser.
  --
  -- gitsigns' <leader>ghd compares ONE file against the index. Diffview shows
  -- every file in a commit, branch or range as a navigable tree, which is what
  -- VSCode's Source Control panel does.
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
    opts = {
      enhanced_diff_hl = true,
      view = {
        -- diff3_mixed shows base + ours + theirs during conflict resolution,
        -- which is where merging in the terminal usually hurts.
        merge_tool = { layout = "diff3_mixed" },
      },
      -- Diffview opens in a new TAB PAGE, not a floating window -- which is why
      -- <Esc> closes nothing, and by default it has no close mapping in the view
      -- or the file panel (only in the option and help panels).
      --
      -- `q` is added to the PANELS only, which are not editable. In the view
      -- itself the diff buffers can be edited, and there `q` has to keep being
      -- macro recording.
      --
      -- Diffview merges keymaps by lhs, not by index (config.lua:643 uses
      -- extend_keymaps), so this adds to the defaults instead of replacing them.
      keymaps = {
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        },
        file_history_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        },
      },
    },
    keys = {
      { "<leader>gvd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: working tree" },
      {
        "<leader>gvb",
        function()
          vim.cmd("DiffviewOpen " .. base_branch() .. "...HEAD")
        end,
        desc = "Diffview: my changes vs base branch",
      },
      { "<leader>gvf", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: this file's history" },
      { "<leader>gvF", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: branch history" },
      { "<leader>gvc", "<cmd>DiffviewClose<cr>", desc = "Diffview: close" },
    },
  },

  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>gv", group = "diffview", mode = { "n", "x" } },
      },
    },
  },
}
