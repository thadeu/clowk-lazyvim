-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Audio files (.mp3, .wav, ...) open in a player instead of as raw bytes.
-- The autocmds live here because LazyVim loads this file BEFORE Neovim reads
-- the file given on the command line (`nvim song.mp3`), which is the only
-- moment early enough for a BufReadCmd to take over the read.
require("config.audio").setup()
