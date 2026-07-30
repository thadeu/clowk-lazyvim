-- Harpoon: stable file anchors.
--
-- cmd+1..5 was given to bufferline instead (see lua/config/keymaps.lua), because
-- what that shortcut means to a VSCode user is tab behaviour: position 1 = first
-- visible tab. Harpoon is a different thing -- its list starts EMPTY and you
-- pick what goes in, so a cmd+1 with nothing anchored does nothing at all. That
-- reads as a bug when you are expecting tabs.
--
-- Worth learning afterwards, though: harpoon positions do not shift when you
-- open other files, which tabs cannot guarantee.
--
-- The plugin itself comes from the `lazyvim.plugins.extras.editor.harpoon2`
-- extra (imported in lua/config/lazy.lua), which already defines:
--   <leader>H       anchor the current file
--   <leader>h       open the menu (reorder / remove)
--   <leader>1..9    jump to anchor N
--
-- This file exists to document that and to be the place for overrides. With no
-- `keys` here, the extra's shortcuts stay exactly as they are.
return {
  "ThePrimeagen/harpoon",
}
