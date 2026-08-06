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

-- Shift + arrows select, the way every other macOS app behaves.
--
-- This is a built-in Vim feature, not a set of mappings: `startsel` makes the
-- shifted special keys (arrows, Home/End, PageUp/Down, and their ctrl+shift
-- word-wise variants) begin a selection, and `stopsel` makes an unshifted one
-- end it. Doing this with keymaps instead would mean re-implementing selection
-- from insert mode by hand, which is where hand-rolled versions get the cursor
-- column wrong.
--
-- `selectmode` stays empty (the default), so this lands in VISUAL mode rather
-- than SELECT mode -- in Select mode any printable key REPLACES the selection,
-- which is VSCode's behaviour but makes every Vim operator unreachable.
opt.keymodel = { "startsel", "stopsel" }

-- Ruby: read by the lazyvim.plugins.extras.lang.ruby extra.
-- These must live here (options load before lazy), not under plugins/.
vim.g.lazyvim_ruby_lsp = "ruby_lsp"
vim.g.lazyvim_ruby_formatter = "rubocop"

-- Machine-local overrides, untracked (see .gitignore and the README).
-- Optional: pcall so a missing file is not an error.
pcall(require, "config.local")
