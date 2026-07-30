-- Installs every language server, linter and formatter this config expects,
-- and BLOCKS until they are on disk.
--
-- Run it with:
--   nvim --headless -c "luafile setup/mason.lua"
--
-- Why a script instead of `nvim --headless "+MasonInstall ..." +qa`, which is
-- the obvious thing to write:
--
--   1. `:MasonInstall` does not exist in that invocation. mason is lazy-loaded,
--      and the command is only created once the plugin is actually loaded, so
--      nvim answers `E492: Not an editor command`.
--
--   2. Even when the command exists, `+qa` quits as soon as the install jobs are
--      SPAWNED. mason prints "Neovim is exiting while packages are still
--      installing. Installation was aborted." and you end up with a half
--      installed mason directory that looks fine until an LSP silently fails to
--      attach.
--
-- The registry API has neither problem: `pkg:install()` starts the job and
-- `vim.wait` pumps the event loop until `pkg:is_installed()` flips.

local PACKAGES = {
  -- nvim-treesitter `main` refuses to install parsers without this one, and the
  -- error only shows up as a health check warning.
  "tree-sitter-cli",

  -- TypeScript / React / Vite / Node / Prisma / Tailwind
  "vtsls",
  "tailwindcss-language-server",
  "prisma-language-server",
  "json-lsp",

  -- Ruby on Rails. These are gems: without ruby/gem on PATH they fail, and the
  -- error message does not mention Ruby at all.
  "ruby-lsp",
  "rubocop",
  "erb-formatter",
  "erb-lint",

  -- Docker / YAML
  "dockerfile-language-server",
  "docker-compose-language-service",
  "hadolint",
  "yaml-language-server",

  -- Markdown
  "markdownlint-cli2",
  "markdown-toc",

  -- Lua, for editing this config
  "lua-language-server",
  "stylua",

  -- Shell, for editing setup/install.sh
  "shfmt",
}

local ok, registry = pcall(require, "mason-registry")

if not ok then
  io.stderr:write("mason-registry not found -- run `nvim --headless \"+Lazy! restore\" +qa` first\n")
  vim.cmd("cquit 1")

  return
end

registry.refresh()

local pending = {}
local unknown = {}

for _, name in ipairs(PACKAGES) do
  local found, pkg = pcall(registry.get_package, name)

  if not found then
    unknown[#unknown + 1] = name
  elseif not pkg:is_installed() then
    -- LazyVim's own ensure_installed may already be installing this package, in
    -- which case install() raises "Package is already installing". Waiting on it
    -- below is still correct, so the error is not fatal.
    pcall(function()
      pkg:install()
    end)
    pending[#pending + 1] = pkg
  end
end

if #pending > 0 then
  print(("mason: installing %d package(s), this takes a few minutes..."):format(#pending))
end

-- 25 min: the gem-backed packages compile native extensions on a cold machine.
vim.wait(1500000, function()
  for _, pkg in ipairs(pending) do
    if not pkg:is_installed() then return false end
  end

  return true
end, 2000)

local failed = {}

for _, name in ipairs(PACKAGES) do
  local found, pkg = pcall(registry.get_package, name)

  if not (found and pkg:is_installed()) then
    failed[#failed + 1] = name
  end
end

for _, name in ipairs(unknown) do
  print("mason: UNKNOWN package " .. name .. " -- renamed upstream?")
end

if #failed > 0 then
  io.stderr:write("mason: FAILED -> " .. table.concat(failed, ", ") .. "\n")
  io.stderr:write("mason: open nvim and run :Mason to see the per-package log\n")
  vim.cmd("cquit 1")

  return
end

print(("mason: %d/%d packages installed"):format(#PACKAGES, #PACKAGES))
vim.cmd("qa!")
