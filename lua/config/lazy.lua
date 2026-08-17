local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- TypeScript stack: React/Vite on the front, Node/Express/Prisma on the back
    { import = "lazyvim.plugins.extras.lang.typescript" },
    { import = "lazyvim.plugins.extras.lang.tailwind" },
    { import = "lazyvim.plugins.extras.lang.prisma" },
    { import = "lazyvim.plugins.extras.lang.json" },
    -- Rails stack: ruby + docker (see lua/plugins/ruby.lua for the setup where
    -- gems live only inside the container)
    { import = "lazyvim.plugins.extras.lang.ruby" },
    { import = "lazyvim.plugins.extras.lang.docker" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    -- markdown: in-buffer rendering + browser preview (see lua/plugins/markdown.lua)
    { import = "lazyvim.plugins.extras.lang.markdown" },
    -- harpoon: base for <leader>1..9 (see lua/plugins/harpoon.lua)
    { import = "lazyvim.plugins.extras.editor.harpoon2" },
    -- PRs and issues inside the editor (see lua/plugins/octo.lua)
    { import = "lazyvim.plugins.extras.util.octo" },
    -- AI autocomplete: Copilot ghost text on <Tab> (see lua/plugins/copilot.lua).
    -- Claude drives the commit messages instead -- see lua/plugins/claude-commit.lua
    -- for why the two jobs went to two different engines.
    { import = "lazyvim.plugins.extras.ai.copilot" },
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
  }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
