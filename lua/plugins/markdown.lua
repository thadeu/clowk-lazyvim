-- Markdown: three layers, each solving a different problem.
--
--   1. render-markdown.nvim (from the lang.markdown extra) prettifies the buffer
--      itself: headings, tables, code blocks, checkboxes. No preview needed for
--      normal reading.
--
--   2. snacks.image renders Mermaid diagrams and LaTeX math INLINE in the
--      buffer, using the Kitty graphics protocol. Ghostty supports it natively
--      (snacks lists kitty, wezterm and ghostty). This is the terminal-native
--      answer to "markdown preview with mermaid" -- no browser involved.
--
--   3. markdown-preview.nvim (also from the extra) opens a live browser preview
--      with full fidelity, for when the inline render is not enough.
--      Toggle with :MarkdownPreviewToggle.
--
-- snacks.image is opt-in (`needs_setup = true`), which is why it is enabled here.
--
-- The same switch also buys the image VIEWER, which has nothing to do with
-- markdown: snacks takes over `BufReadCmd` for png, jpg, jpeg, gif, bmp, webp,
-- tiff, heic, avif, icns, pdf and the first frame of mp4/mov/avi/mkv/webm, so
-- `:e logo.png` -- or picking one in the sidebar -- draws the picture instead
-- of its bytes.
--
-- `svg` is deliberately NOT in that list: it is source code, and adding it
-- would make every svg in a repo unopenable for editing. To trade that away,
-- set `formats` here -- the option REPLACES the default list, so spell all of
-- it out plus "svg".
--
-- Audio is the one media type snacks does not cover; lua/config/audio.lua
-- plays it.
--
-- External tools:
--   mmdc    -- required for Mermaid.  brew install mermaid-cli
--              mmdc draws in a headless Chrome that Homebrew does not pull in.
--              Without it every diagram fails with `Could not find
--              chrome-headless-shell`; the fix is one command, once:
--                npx puppeteer browsers install chrome-headless-shell
--   magick  -- required for svg/pdf/raster images (not for Mermaid).
--              brew install imagemagick
-- Check what is detected with :checkhealth snacks
return {
  {
    "folke/snacks.nvim",
    opts = {
      image = {
        enabled = true,
        doc = {
          -- Render inline in the buffer rather than in a floating window.
          -- Needs unicode placeholder support; snacks falls back to `float`
          -- automatically when the terminal cannot do it.
          inline = true,
          float = true,
          -- Diagrams get more room than the 80x40 default, since a Mermaid
          -- flowchart at 80 columns is usually unreadable.
          max_width = 100,
          max_height = 50,
        },
      },
    },
  },

  -- markdownlint is off on purpose.
  --
  -- The lang.markdown extra wires markdownlint-cli2 in TWICE: as an nvim-lint
  -- linter, which runs on every save, and as a conform formatter, which runs
  -- `--fix` whenever one of those diagnostics is open on the buffer. Its rules
  -- police the SHAPE of the file rather than whether it reads well -- MD013
  -- line length, MD033 inline HTML, MD024 duplicate headings -- so prose
  -- written normally lights the buffer up, and the auto-fix then rewrites
  -- lines nobody touched. Every one of those rewrites lands in `git diff`.
  --
  -- What stays: marksman, so broken links and references are still reported,
  -- and prettier in the conform chain below. prettier is NOT installed by
  -- setup/mason.lua, so on a clean machine nothing rewrites a markdown buffer
  -- on save any more -- `:ConformInfo` in a markdown file shows the whole
  -- chain and which part of it is missing.
  --
  -- Removing it here is not enough by itself. setup/mason.lua no longer
  -- installs the binary, and lua/plugins/mason.lua filters it out of what the
  -- extra pushes into mason's `ensure_installed`; without that second step it
  -- reinstalls itself at the next startup.
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        markdown = {},
      },
    },
  },

  -- lazy.nvim REPLACES lists rather than merging them, so this is the whole
  -- formatter chain for markdown, minus markdownlint-cli2.
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        ["markdown"] = { "prettier", "markdown-toc" },
        ["markdown.mdx"] = { "prettier", "markdown-toc" },
      },
    },
  },
}
