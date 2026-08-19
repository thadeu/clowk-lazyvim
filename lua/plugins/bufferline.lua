-- The buffer tabs must not run over the sidebar.
--
-- bufferline shifts the tabline right by the width of a window it recognises,
-- through `offsets`. LazyVim lists `snacks_layout_box` there, which worked
-- while the picker WAS the top of the left column. It is not any more: the
-- activity bar sits above it (lua/config/sidebar.lua), and bufferline only
-- ever looks at the TOPMOST window of a column (`iterate_col_layout` in
-- bufferline/offset.lua) -- so it stopped finding anything to offset by, and
-- the tabs went back to spanning the whole screen.
--
-- One entry is enough because the bar is the top of that column for every
-- panel: explorer, find and replace, source control. grug-far gains an offset
-- it never had -- LazyVim's list only ever named the tree.
return {
  "akinsho/bufferline.nvim",
  opts = function(_, opts)
    opts.options = opts.options or {}
    opts.options.offsets = opts.options.offsets or {}

    table.insert(opts.options.offsets, 1, { filetype = "clowk_sidebar" })
  end,
}
