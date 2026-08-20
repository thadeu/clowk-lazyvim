-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Spell check off for prose files.
--
-- LazyVim's `wrap_spell` autocmd sets BOTH `wrap = true` and `spell = true`
-- for text, plaintex, typst, gitcommit and markdown. The wrap half is wanted;
-- the spell half is not. `SpellBad` in colors/clowk-night.lua is a red
-- undercurl -- the same mark a diagnostic uses -- so a README full of product
-- names, CLI flags and code spans (FreeSWITCH, gosu, cap_sys_nice) reads as a
-- file full of errors, and none of them are errors.
--
-- Deleting the whole `lazyvim_wrap_spell` group would take `wrap` with it, so
-- only the option is put back. This autocmd is created AFTER LazyVim's --
-- lua/config/autocmds.lua is loaded once lazyvim.config.autocmds is done --
-- and FileType autocmds run in creation order, so this one has the last word.
--
-- `<leader>us` turns spelling back on for the buffer in front of you.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("no_spell", { clear = true }),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  desc = "Undo LazyVim's spell = true, keep its wrap = true",
  callback = function()
    vim.opt_local.spell = false
  end,
})

-- Audio files (.mp3, .wav, ...) open in a player instead of as raw bytes.
-- The autocmds live here because LazyVim loads this file BEFORE Neovim reads
-- the file given on the command line (`nvim song.mp3`), which is the only
-- moment early enough for a BufReadCmd to take over the read.
require("config.audio").setup()
