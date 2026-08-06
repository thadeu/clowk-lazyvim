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

  -- Docker / YAML
  "dockerfile-language-server",
  "docker-compose-language-service",
  "hadolint",
  "yaml-language-server",

  -- Markdown
  "markdownlint-cli2",

  -- Lua, for editing this config
  "lua-language-server",
  "stylua",

  -- Shell, for editing setup/install.sh
  "shfmt",
}

-- Removed on purpose, because they fail often enough to take the whole install
-- down with them, and neither is load-bearing:
--
--   erb-formatter, erb-lint  gems that compile native extensions (erb-lint
--                            pulls better_html), so they need a working C
--                            toolchain on top of a recent Ruby. Only used for
--                            Rails ERB templates.
--   markdown-toc             generates a table of contents in markdown, and
--                            nothing here calls it.
--
-- To bring one back, put it in the list below (or in PACKAGES) and re-run
-- setup/install.sh -- or just `:MasonInstall <name>` from inside Neovim.

-- These are gems, so they need a host Ruby -- and a recent one. Checking that
-- `ruby` merely exists is not enough: macOS ships 2.6.10 with a working `gem`,
-- and mason's failure on a machine like that never mentions Ruby at all.
local RUBY_PACKAGES = {
  "ruby-lsp",
  "rubocop",
}

local MIN_RUBY = "3.2.0"

--- Host Ruby version as {major, minor, patch}, or nil when there is no ruby.
local function ruby_version()
  if vim.fn.executable("ruby") == 0 then
    return nil
  end

  local out = vim.fn.system({ "ruby", "-e", "print RUBY_VERSION" })

  return vim.v.shell_error == 0 and vim.version.parse(out) or nil
end

local host_ruby = ruby_version()

if host_ruby and not vim.version.lt(host_ruby, MIN_RUBY) then
  vim.list_extend(PACKAGES, RUBY_PACKAGES)
elseif host_ruby then
  print(("mason: SKIP ruby packages -- host ruby is %s, ruby-lsp needs %s+"):format(tostring(host_ruby), MIN_RUBY))
else
  print("mason: SKIP ruby packages -- no ruby on PATH")
end

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

-- Wait, reporting what is still outstanding every 15s.
--
-- Without this the script is silent for as long as it takes, and a genuinely
-- stuck package is indistinguishable from a slow one -- "mason is hanging" with
-- no name attached is not something you can act on. Naming the stragglers turns
-- it into "it is stuck on X", which you can.
--
-- 10 min, down from 25: the packages that justified the longer wait were the
-- gems compiling native extensions, and those are gone. A package that has not
-- landed in 10 minutes is stuck, not slow, and failing then beats another
-- quarter of an hour of silence.
local TIMEOUT_MS = 600000
local TICK_MS = 2000
local REPORT_EVERY = 15000

-- Wall clock, not a counter incremented per callback: vim.wait calls the
-- predicate on events too, not only every TICK_MS, so counting calls reports a
-- time that drifts away from the real one.
local uv = vim.uv or vim.loop
local started = uv.hrtime()
local last_report = 0

local function elapsed_ms()
  return (uv.hrtime() - started) / 1e6
end

local ok_all = vim.wait(TIMEOUT_MS, function()
  local outstanding = {}

  for _, pkg in ipairs(pending) do
    if not pkg:is_installed() then
      outstanding[#outstanding + 1] = pkg.name
    end
  end

  if #outstanding == 0 then
    return true
  end

  local now = elapsed_ms()

  if now - last_report >= REPORT_EVERY then
    last_report = now
    print(("mason: %ds -- waiting on %d: %s"):format(now / 1000, #outstanding, table.concat(outstanding, ", ")))
  end

  return false
end, TICK_MS)

if not ok_all then
  print(("mason: TIMEOUT after %d minutes"):format(TIMEOUT_MS / 60000))
end

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
