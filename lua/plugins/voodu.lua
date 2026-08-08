-- voodu (self-hosted PaaS) manifests: *.voodu files are HCL.
--
-- The extension -> filetype mapping is in lua/config/options.lua (it has to run
-- before lazy). This only makes sure the parser that does the highlighting is
-- actually installed.

return {
  "nvim-treesitter/nvim-treesitter",
  opts = { ensure_installed = { "hcl" } },
}
