-- Packages this config refuses to install, no matter who asks for them.
--
-- setup/mason.lua dropping a name is not enough: it only governs the list the
-- installer walks explicitly. LazyVim's language extras ALSO push names into
-- mason's `ensure_installed`, and mason acts on that at startup --
--
--   extras/lang/markdown.lua  ->  markdown-toc
--   extras/lang/ruby.lua      ->  erb-formatter, erb-lint
--
-- -- so the three kept reinstalling themselves after being removed from the
-- installer. This filters them back out of whatever the extras built.
--
-- Why these three: erb-formatter and erb-lint are gems that compile native
-- extensions (erb-lint pulls better_html), so they want a C toolchain on top of
-- a recent Ruby, and they only touch Rails ERB templates. markdown-toc
-- generates a table of contents nothing here asks for. All three failed the
-- install on a second machine.
--
-- To bring one back, delete it from DROP and re-run setup/install.sh.

local DROP = {
  ["markdown-toc"] = true,
  ["erb-formatter"] = true,
  ["erb-lint"] = true,
}

return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(pkg)
        return not DROP[pkg]
      end, opts.ensure_installed or {})
    end,
  },
}
