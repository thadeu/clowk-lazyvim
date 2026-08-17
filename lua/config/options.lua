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

-- AI completions as inline ghost text, not as rows in the completion menu.
--
-- This one flag is what makes Copilot behave the way it does in VSCode and
-- Cursor: the suggestion is drawn ahead of the cursor in grey and <Tab> takes
-- it. LazyVim defaults it to true, which instead hides Copilot inside the
-- blink.cmp popup among the LSP entries, where a multi-line suggestion cannot
-- be shown at all.
--
-- Three separate settings read it, which is why it is a global and not an
-- option on one plugin: copilot.lua turns its own ghost text on (`suggestion`),
-- blink.cmp turns ITS ghost text off so the two do not draw over each other,
-- and blink's <Tab> becomes "accept the AI suggestion, otherwise fall through".
--
-- Like the Ruby settings above, this must be set before lazy.nvim starts -- the
-- extras read it while their specs are being evaluated.
vim.g.ai_cmp = false

-- voodu manifests are HCL. The extension is not registered anywhere, so without
-- this they open as plain text.
--
-- This has to live in options (loaded before lazy) rather than in autocmds,
-- which LazyVim defers to VeryLazy -- by then the first file's filetype has
-- already been decided.
vim.filetype.add({
  extension = { voodu = "hcl" },
})

-- Machine-local overrides, untracked (see .gitignore and the README).
-- Optional: pcall so a missing file is not an error.
pcall(require, "config.local")
