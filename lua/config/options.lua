-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

-- Horizontal scrolling.
--
-- LazyVim sets sidescrolloff = 8, which demands 8 columns of slack between the
-- cursor and the window edge. With wrap = false that makes the window scroll
-- sideways as soon as the cursor gets near the visible end -- even while the
-- text is still far from the edge. The side effect is the left side of the file
-- being cut off.
--
-- 0 = only scroll once the cursor actually reaches the edge.
opt.sidescrolloff = 0

-- Scroll one column at a time. Neovim's default is 0, which jumps half a screen
-- and is far more disorienting. LazyVim already fixes this; it is spelled out
-- here because the two options only make sense together.
opt.sidescroll = 1

-- Alternative, to remove horizontal scrolling entirely: uncomment the lines
-- below and lines wrap at the window width instead of scrolling.
-- Quick toggle without editing this file: <leader>uw
-- opt.wrap = true
-- opt.breakindent = true -- keep indentation on wrapped continuation lines

-- Ruby: read by the lazyvim.plugins.extras.lang.ruby extra.
-- These must live here (options load before lazy), not under plugins/.
vim.g.lazyvim_ruby_lsp = "ruby_lsp"
vim.g.lazyvim_ruby_formatter = "rubocop"

-- Machine-local overrides, untracked (see .gitignore and the README).
-- Optional: pcall so a missing file is not an error.
pcall(require, "config.local")
