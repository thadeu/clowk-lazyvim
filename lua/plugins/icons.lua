-- Two glyphs replaced, and the choice was measured rather than eyeballed.
--
-- A terminal fits a Nerd Font glyph to the cell, so what decides whether an
-- icon towers over the text beside it is the glyph's OWN aspect ratio -- the
-- taller and narrower it is drawn, the more the fit blows it up. Ghostty's
-- documentation says as much about `adjust-icon-height`: "the effect depends on
-- whether the default size of the icon is height-constrained, which in turn
-- depends on the aspect ratio of both the icon and your primary font".
--
-- Every glyph mini.icons hands out was measured against the font this config
-- ships (`fontTools`, MesloLGS Nerd Font Mono, 1040 entries). The Material
-- Design set -- `nf-md-*`, which is where nearly all of them come from -- is
-- drawn on one grid: 1233 units wide, every one of them, with heights between
-- 886 and 1710. A capital `M` is 1059 x 1488, a ratio of 1.41. The two below
-- are not from that set and are not on that grid:
--
--   i_seti_yml    634 x 1864   ratio 2.94   the `!` that started this
--   i_seti_shell  996 x 1863   ratio 1.87
--
-- Their replacements are from the Material Design grid, and say the same thing:
--
--   file-cog     1237 x 1366   ratio 1.10   a file that is configuration
--   bash         1233 x 1060   ratio 0.86
--
-- Everything else above 1.5 is either a filetype nobody here opens (smarty,
-- solidity, matlab) or one of mini.icons' `alpha-*` letters, the fallback for
-- the hundreds of filetypes with no icon of their own. Those are 1.67 -- 18%
-- over the `M` -- and there are some five hundred of them. Not worth the churn.
--
-- The colours are the ones mini.icons already chose; only the glyph changes.
--
-- Spelled by codepoint, because these live in the private use area and a
-- private-use character does not survive every editor, shell and pipe on the
-- way into a file. Written as glyphs elsewhere in this config, they arrived as
-- empty strings.
local FILE_COG = vim.fn.nr2char(0xf107b)
local BASH = vim.fn.nr2char(0xf1183)

local function shell(hl)
  return { glyph = BASH, hl = hl }
end

return {
  {
    "nvim-mini/mini.icons",
    opts = {
      filetype = {
        -- One entry covers `.yml`, `.yaml` and every `compose.yml`: the
        -- extensions resolve through the filetype, not around it.
        yaml = { glyph = FILE_COG, hl = "MiniIconsPurple" },

        sh = shell("MiniIconsGrey"),
        bash = shell("MiniIconsGreen"),
        zsh = shell("MiniIconsGreen"),
        fish = shell("MiniIconsGrey"),
        csh = shell("MiniIconsGrey"),
        ksh = shell("MiniIconsGrey"),
        awk = shell("MiniIconsGrey"),
        nu = shell("MiniIconsPurple"),
      },
    },
  },
}
