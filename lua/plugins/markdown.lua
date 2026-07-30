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
-- External tools:
--   mmdc    -- required for Mermaid.  brew install mermaid-cli
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
}
