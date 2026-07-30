-- Octo: GitHub PRs and issues inside the editor.
--
-- The closest thing to VSCode's PR panel: opens a PR in a buffer with its
-- description and comments, lets you reply, review file by file and approve.
-- Uses the `gh` CLI underneath, so it needs `gh auth login` first.
--
-- Works against GitHub Enterprise too: octo derives the host from the repo's
-- git remote, so a self-hosted instance needs no extra configuration.
--
-- Shortcuts: <leader>gp (list PRs), <leader>gP (search), <leader>gi / <leader>gI
-- for issues. Inside an octo buffer, actions live under <localleader>.
--
-- NOTE: the LazyVim extra sets `picker = "telescope"`, but this config uses the
-- snacks picker and does NOT install telescope -- octo would come up with no
-- working picker. The override below switches it to snacks.
--
-- Verified against octo's source: it resolves `octo.pickers.<picker>.provider`
-- (picker.lua:54), and `octo.pickers.snacks.provider` exists.
return {
  {
    "pwntester/octo.nvim",
    opts = {
      picker = "snacks",
    },
  },
}
