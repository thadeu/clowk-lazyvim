-- Diagnostics as a popup on the line, the way VSCode does it -- not as text
-- written into the buffer.
--
-- LazyVim draws every diagnostic as virtual text at the END of the logical
-- line (lsp/init.lua: prefix "●", source "if_many"). For code that is fine,
-- because a line of code is short. For markdown it is the worst possible
-- place: LazyVim also sets wrap = true for markdown (the wrap_spell autocmd),
-- so the end of a 151-column line is somewhere in the MIDDLE of the screen.
-- The message then lands between the visual rows of a table and reads as if
-- somebody wrote it on top of the text.
--
-- The line is still marked, in two places that cost no horizontal room:
-- a sign in the gutter and an underline below the offending columns. The text
-- of the message moves into a float:
--
--   * on hover   -- the CursorHold autocmd below. updatetime is 200ms
--                   (LazyVim), so the popup opens after a short pause.
--   * on demand  -- <leader>cd, a LazyVim keymap. Press it twice to move INTO
--                   the float, for example to copy the message. This is why
--                   `focusable = false` is set on the autocmd call only and
--                   not in the shared `float` options below.
--
-- <leader>ud still turns diagnostics off completely.

vim.api.nvim_create_autocmd("CursorHold", {
  group = vim.api.nvim_create_augroup("diagnostic_hover", { clear = true }),
  desc = "Show the diagnostics of the line in a float",
  callback = function()
    -- The cursor is already in a float (hover, completion docs, or this same
    -- popup). A second float would stack on the first one.
    if vim.api.nvim_win_get_config(0).relative ~= "" then
      return
    end

    vim.diagnostic.open_float({
      scope = "line",
      focusable = false,
    })
  end,
})

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        virtual_text = false,
        float = {
          border = "rounded",
          source = true,
          header = "",
        },
      },
    },
  },
}
