-- VSCode's activity bar, as far as Neovim can take it.
--
-- ONE docked window on the left, and a row of clickable icons at the top of it
-- that decides what the window shows:
--
--   󰉋  explorer  snacks.explorer -- the same tree <leader>e opens
--   󰍉  search    grug-far -- find and replace across the project
--   󰊢  git       snacks git_status -- the changed files, and the diff of the
--                selected one in the MAIN window. That is not a trick: the
--                `sidebar` layout renders its preview in the editor area, which
--                is exactly where VSCode puts the diff.
--
-- Only ONE panel is open at a time. That is what makes the three read as a
-- sidebar instead of as three unrelated windows: opening one closes the others,
-- and clicking the icon of the open one closes the sidebar.
--
-- The icon row is a `winbar`, which is the only part of a window Neovim lets
-- you draw AND click: in `%<n>@Fn@text%X` a click calls Fn(n), so each icon
-- carries its own index. Two details are not obvious:
--
--   * a floating window does render a winbar (the pickers are floats), but the
--     row has to fit -- hence `height = 2` on the input box below, one row for
--     the icons and one for the filter line.
--   * the winbar must be handed to snacks as a window option (`wo`). Setting it
--     later with `vim.wo` is undone: snacks re-applies its own `wo` table on
--     every layout update.

local M = {}

-- 40 is the snacks `sidebar` preset width, and its minimum.
M.width = 40

-- grug-far is wider because its result lines are `file:line:col:text`. At 40
-- columns every hit wraps over three rows and the panel stops being readable.
M.width_search = 60

local INSTANCE = "sidebar"

--- The grug-far window, so the panel can tell "focus me" from "close me".
--- The pickers answer that themselves; grug-far has no such question.
---@type integer?
local search_win

--- The two looks of a tab: dim, and a lit block for the one that is open.
---
--- Built from the colorscheme's own groups rather than linked to them, because
--- a link carries EVERY attribute of its target -- the active tab needs the
--- foreground of one group and the background of another, which is a thing no
--- single link can say. Re-run on ColorScheme for the same reason.
local function set_hl()
  local function hl(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false })
  end

  vim.api.nvim_set_hl(0, "ClowkSidebarTab", { fg = hl("Comment").fg, bold = true })
  vim.api.nvim_set_hl(0, "ClowkSidebarHeader", { fg = hl("Title").fg, bold = true })
  -- The same colour as the line Neovim draws between windows, so the rule
  -- inside the bar and the one under it read as the same kind of border.
  vim.api.nvim_set_hl(0, "ClowkSidebarDivider", { fg = hl("WinSeparator").fg })
  vim.api.nvim_set_hl(0, "ClowkSidebarTabActive", {
    fg = hl("Title").fg,
    bg = hl("CursorLine").bg,
    bold = true,
  })
end

set_hl()

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("clowk_sidebar_hl", { clear = true }),
  callback = set_hl,
})

--- The glyph of each button.
---
--- Neovim cannot make a glyph bigger: it writes characters into cells, and the
--- drawing belongs to the terminal font (in Ghostty the knobs are
--- `adjust-icon-height` and `font-size` -- see setup/ghostty/config). What IS
--- ours is WHICH glyph gets drawn, and they are not all cut to the same optical
--- size: the Font Awesome ones below carry noticeably more ink per cell than
--- the thinner Material Design set they replace.
---
--- Read on every redraw, so changing this table shows up without a restart.
M.icons = {
  explorer = "", -- nf-fa-folder      U+F07B
  search = "", -- nf-fa-search      U+F002
  git = "", -- nf-fa-code_fork   U+F126
}

---@type { name: string, desc: string }[]
local tabs = {
  { name = "explorer", desc = "Explorer" },
  { name = "search", desc = "Find and replace" },
  { name = "git", desc = "Source control" },
}

--- What the open panel is called, the way VSCode heads its sidebar sections.
---
--- The explorer is named after the project rather than after itself, which is
--- what makes the bar answer "where am I" and not only "what is this".
---@param active string
local function header(active)
  if active == "git" then
    return "CHANGES"
  end

  if active == "search" then
    return "SEARCH"
  end

  if active == "explorer" then
    -- The tree's own root, not the current file's: the panel is showing that
    -- directory, whatever buffer happens to be open beside it.
    local p = Snacks.picker.get({ source = "explorer" })[1]
    local ok, root = pcall(function()
      return p and p:cwd() or nil
    end)

    return vim.fs.basename(ok and root or vim.uv.cwd()):upper()
  end

  return ""
end

--- How tall the activity bar is, in rows. See `bar_render` for what each row
--- becomes; 4 is the banded VSCode look: rule, buttons, rule, label.
M.bar_height = 4

--- Spaces inside a button, around the icon. This is the whole of the lit block
--- on the open one: a light padding, not a filled third of the bar.
M.bar_pad = 1

--- Spaces between two buttons, and before the first. Half of a gap on each
--- side still COUNTS as the button when clicked -- the target stays bigger
--- than the block it draws.
M.bar_gap = 2

local ns = vim.api.nvim_create_namespace("clowk_sidebar_bar")

---@type integer? the bar window
local bar_win

--- Which bar is on screen. Every raise bumps it, and the WinClosed watcher of
--- an OLD panel checks it before pulling anything down -- otherwise switching
--- panels kills the bar that was just built: the watcher fires when the old
--- panel closes, but its scheduled callback runs after the new bar is already
--- up, and closes that one instead.
local bar_gen = 0
---@type integer? the bar buffer, kept between openings
local bar_buf

--- Which panel the bar is drawn for.
---
--- Kept here rather than read from `M.current` on every redraw: the explorer
--- opens by itself on `nvim .`, without passing through `M.open`, and a redraw
--- (a resize, say) would then find `M.current` empty and quietly rub out both
--- the lit button and the header.
---@type string
local bar_active = ""

--- Which button covers which columns. Rebuilt on every render, read by the
--- click handler -- one source of truth for where a button is.
---@type { name: string, from: integer, to: integer }[]
local slots = {}

--- The 1-based line the header sits on, so a click on the label is not read as
--- a click on the button above it. Every other row of the bar counts: the
--- target is one column wide but the full height of the button area.
---@type integer?
local head_line

--- Draw the bar: a row of buttons, and the name of the panel under them.
---
--- Buffer TEXT, not a `winbar`: a winbar is exactly one row, and the point of
--- this window is to have height. The cost is that text is not clickable the
--- way a winbar is, which is what the `<LeftMouse>` map below pays for.
---
--- The header takes the last row and the buttons are centred in what is left,
--- so a two-row bar reads as buttons over a title -- and a four-row one puts a
--- blank line on each side of the buttons. A two-row box has no middle row to
--- put them in; that is arithmetic, not a decision.
---@param active string
local function bar_render(active)
  if not (bar_win and vim.api.nvim_win_is_valid(bar_win)) then
    return
  end

  bar_active = active or bar_active

  local pad = (" "):rep(M.bar_pad)
  local gap = (" "):rep(M.bar_gap)
  local line, cells, marks = "", 0, {}

  slots = {}

  for _, tab in ipairs(tabs) do
    -- A gap before every button, the first one included: that leading one is
    -- the left margin, and it keeps the row off the edge of the panel.
    line, cells = line .. gap, cells + M.bar_gap

    local icon = M.icons[tab.name]
    local text = pad .. icon .. pad
    local width = 2 * M.bar_pad + vim.fn.strdisplaywidth(icon)

    -- Two coordinate systems, and they are not the same: extmarks want BYTES,
    -- the mouse answers in display CELLS. An icon is one cell and three bytes.
    -- `false`, not `0`: the row of the buttons is only known further down, and
    -- a numeric placeholder collides with the top rule, which really does live
    -- on row 0. That collision moved a full-width rule onto the short button
    -- line: `Invalid 'end_col': out of range`.
    marks[#marks + 1] = {
      row = false,
      from = #line,
      to = #line + #text,
      hl = tab.name == active and "ClowkSidebarTabActive" or "ClowkSidebarTab",
    }

    -- The click takes the block plus half a gap on each side. Drawing a small
    -- button and demanding a small aim are two different things.
    slots[#slots + 1] = {
      name = tab.name,
      from = cells + 1 - math.floor(M.bar_gap / 2),
      to = cells + width + math.floor(M.bar_gap / 2),
    }

    line, cells = line .. text, cells + width
  end

  -- The bar, from the bottom up: the label takes the last row, a rule the one
  -- above it, and a second rule the very top -- each only once there is a row
  -- to spare for it. What is left over is where the buttons go, in the middle
  -- of it.
  --
  --   4 rows   rule / buttons / rule / label   (VSCode's banding)
  --   3 rows   buttons / rule / label
  --   2 rows   buttons / label
  --   1 row    buttons
  local rows = math.max(M.bar_height, 1)
  local head_row = rows > 1 and rows - 1 or nil
  local div_row = rows > 2 and head_row - 1 or nil
  local top_row = rows > 3 and 0 or nil
  local first = top_row and 1 or 0
  local last = (div_row or head_row or rows) - 1
  local icon_row = math.floor((first + last) / 2)
  local lines = {}

  for i = 1, rows do
    lines[i] = ""
  end

  lines[icon_row + 1] = line

  head_line = head_row and head_row + 1 or nil

  local rule = ("─"):rep(vim.api.nvim_win_get_width(bar_win))
  local rules = {}

  -- Built by hand rather than as `{ top_row, div_row }`: a nil in the first
  -- slot ends an ipairs before it starts, and at three rows the top rule is
  -- exactly that nil -- the divider would go missing with it.
  for _, row in ipairs({ top_row or -1, div_row or -1 }) do
    if row >= 0 then
      rules[#rules + 1] = row
    end
  end

  for _, row in ipairs(rules) do
    lines[row + 1] = rule
    marks[#marks + 1] = { row = row, from = 0, to = #rule, hl = "ClowkSidebarDivider" }
  end

  if head_row then
    -- Indented by the same gap as the first button, so the label starts where
    -- the row of buttons starts instead of hugging the edge on its own.
    local title = gap .. header(active)

    lines[head_row + 1] = title
    marks[#marks + 1] = { row = head_row, from = 0, to = #title, hl = "ClowkSidebarHeader" }
  end

  for _, mark in ipairs(marks) do
    if mark.row == false then
      mark.row = icon_row
    end
  end

  vim.bo[bar_buf].modifiable = true
  vim.api.nvim_buf_set_lines(bar_buf, 0, -1, false, lines)
  vim.bo[bar_buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(bar_buf, ns, 0, -1)

  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(bar_buf, ns, mark.row, mark.from, {
      end_col = mark.to,
      hl_group = mark.hl,
    })
  end
end

--- Clicks on the bar, wherever the cursor happens to be.
---
--- Global and not buffer-local, which is the whole trick. A buffer-local
--- `<LeftMouse>` on the bar never fires: Neovim resolves the mapping in the
--- buffer that is ALREADY current, and moving to the clicked window is what
--- the default `<LeftMouse>` does afterwards. A buffer-local map would
--- therefore only answer clicks made from inside the bar -- which is the one
--- place nobody clicks from.
---
--- An `<expr>` map with `remap = false` gives back the very key it caught when
--- the click is not ours, so every other click in the editor behaves exactly
--- as it did.
local function bar_mouse()
  local pos = vim.fn.getmousepos()

  if not (bar_win and pos.winid == bar_win) then
    return "<LeftMouse>"
  end

  -- The label is not a button, even where it sits under one.
  if head_line and pos.line == head_line then
    return ""
  end

  for _, s in ipairs(slots) do
    if pos.wincol >= s.from and pos.wincol <= s.to then
      -- Scheduled twice over: an expr mapping runs under textlock and may not
      -- touch windows at all, and snacks is still unwinding the WinLeave of
      -- the panel being left (`list.lua: attempt to index field 'picker'`).
      vim.schedule(function()
        M.toggle(s.name)
      end)

      break
    end
  end

  return ""
end

vim.keymap.set({ "n", "i", "v" }, "<LeftMouse>", bar_mouse, {
  expr = true,
  replace_keycodes = true,
  desc = "Sidebar: switch panel (activity bar)",
})

vim.keymap.set({ "n", "i", "v" }, "<2-LeftMouse>", function()
  local pos = vim.fn.getmousepos()

  return (bar_win and pos.winid == bar_win) and "" or "<2-LeftMouse>"
end, { expr = true, replace_keycodes = true, desc = "Sidebar: swallow double click on the bar" })

--- Take the bar down. Called before any panel change: while it is up, the next
--- picker would open its own `:topleft vsplit` as a NEW leftmost column and the
--- bar would end up beside the sidebar rather than above it.
local function bar_close()
  if bar_win and vim.api.nvim_win_is_valid(bar_win) then
    pcall(vim.api.nvim_win_close, bar_win, true)
  end

  bar_win = nil
end

--- Put the bar above `win`, inside the same column.
---
--- `nvim_open_win` with `split`/`win` rather than `:split`: the picker holds
--- the focus, and a `:split` command would carve the window the cursor happens
--- to be in -- which is the editor, on the other side of the screen.
---@param win integer the panel window
---@param active string
local function bar_open(win, active)
  bar_close()

  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end

  if not (bar_buf and vim.api.nvim_buf_is_valid(bar_buf)) then
    bar_buf = vim.api.nvim_create_buf(false, true)

    vim.bo[bar_buf].filetype = "clowk_sidebar"
  end

  bar_gen = bar_gen + 1
  bar_win = vim.api.nvim_open_win(bar_buf, false, {
    win = win,
    split = "above",
    height = M.bar_height,
  })

  -- A bar is not a text window: no numbers, no cursor, no fold or sign gutter
  -- eating the columns the buttons are measured against.
  local wo = vim.wo[bar_win]

  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.statuscolumn = ""
  wo.cursorline = false
  wo.wrap = false
  -- LazyVim draws trailing whitespace as `-` (listchars). The padding around
  -- the buttons IS trailing whitespace, so the bar came out with a dashed tail.
  wo.list = false
  wo.winfixheight = true
  wo.winfixwidth = true

  bar_render(active)
end

--- Take the bar down with the panel, whichever way the panel goes.
---
--- `q` inside a picker, `<esc>`, a window closed by hand: none of those pass
--- through this module, and a bar left alone in the column would be the only
--- thing on that side of the screen.
---@param win integer the panel window
local function bar_follow(win)
  local gen = bar_gen

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      vim.schedule(function()
        if bar_gen == gen then
          bar_close()
        end
      end)
    end,
  })
end

--- The snacks `sidebar` preset, with room for the icon row.
---
--- Copied out rather than extended through `preset = "sidebar"`: a layout
--- passed by the caller REPLACES the preset instead of merging with it
--- (picker/config/init.lua only resolves presets when `layout.layout` is
--- empty), so a partial table loses the root box and the picker fails to open.
---@param preview boolean|string false for the explorer, "main" to draw the
---       preview in the editor window instead of inside the sidebar
---@param width? integer
local function layout(preview, width)
  -- A missing width is not a small mistake here: snacks reads it as "no width
  -- given", grows the split over the whole editor and leaves the file with the
  -- 20 columns of `winwidth`. Never let it be nil.
  width = width or M.width or 40

  return {
    preview = preview,
    -- The filter line is off by default: a panel that is READ (a tree, a list
    -- of changed files) does not need a prompt sitting over it. `/` brings it
    -- back and focuses it, `<esc>` puts it away again -- both are wired in
    -- `keys` below.
    hidden = { "input" },
    layout = {
      backdrop = false,
      width = width,
      min_width = width,
      height = 0,
      position = "left",
      border = "none",
      box = "vertical",
      { win = "input", height = 1, border = true, title = "{title} {live} {flags}", title_pos = "center" },
      { win = "list", border = "none" },
      { win = "preview", title = "{preview}", height = 0.4, border = "top" },
    },
  }
end

--- The windows of a picker panel: the icon row, and the two keys that show and
--- hide the filter line.
---
--- The icon row rides on the LIST window, not on the input one -- the input is
--- hidden, and a winbar on a window that is not on screen draws nothing.
---@param active string
local function wins(active)
  return {
    list = {
      keys = {
        -- snacks binds `/` to `toggle_focus`, which moves the cursor into an
        -- input that is not there any more.
        ["/"] = "toggle_input",
      },
    },
    input = {
      keys = {
        -- `<esc>` in the input is `cancel`, which closes the whole picker.
        -- Inside a sidebar that reads as losing the panel for a typo; here it
        -- only ends the filtering. The sidebar itself closes with its own key
        -- or its own icon.
        ["<esc>"] = { "toggle_input", mode = { "n", "i" } },
      },
    },
  }
end

---@param source string
local function picker(source)
  return Snacks.picker.get({ source = source })[1]
end

--- Close the "before" side of a diff this panel opened.
---
--- Found by the buffer name rather than by a stored handle: the window can also
--- be closed by hand, and a handle would then point at nothing while a second
--- <cr> opened a third pane.
local function diff_close()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))

    if name:match("^sidebar%-diff://") then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

--- The two panes: the file as the index has it on the left, the working tree on
--- the right. VSCode's diff editor, and `<cr>` in the panel opens it.
---
--- Built here rather than with `Gitsigns diffthis`, which looks like the ready
--- made answer and is not. gitsigns diffs the buffer you are ALREADY sitting
--- in, and only once its own asynchronous read of the index has finished. On a
--- file that `jump` opened a millisecond earlier neither holds: it fails with
--- `assertion failed!` on `compare_text`, thrown inside its async runner where
--- no pcall of ours can reach it. Waiting for the attach is not enough either
--- -- the attach lands before the text does.
---
--- `git show :0:<path>` is the same content, synchronously, in one call.
---@param item snacks.picker.Item?
local function diff_open(_, item)
  -- An untracked file has no other side to compare against.
  if not item or not item.file or (item.status or ""):find("?", 1, true) then
    return
  end

  local root = vim.fs.normalize(item.cwd or vim.uv.cwd())
  local rel = item.file
  local abs = vim.fs.normalize(rel:sub(1, 1) == "/" and rel or (root .. "/" .. rel))

  -- git wants the path as the repository names it, whatever the item carried.
  rel = abs:sub(#root + 2)

  local tries = 0

  --- The window the file landed in.
  ---
  --- Looked up rather than assumed. "The current window" is wrong more often
  --- than it looks: with `preview = "main"` the editor window is still showing
  --- the preview buffer for a tick or two after `jump`, the file may already be
  --- open somewhere else, and a click leaves the cursor wherever it clicked.
  local function target()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))

      if vim.fs.normalize(name) == abs and not vim.wo[win].diff then
        return win
      end
    end
  end

  local function attempt()
    local win = target()

    if not win then
      tries = tries + 1

      if tries < 20 then
        vim.defer_fn(attempt, 30)
      else
        vim.notify(("sidebar: %s never reached a window, no diff"):format(rel), vim.log.levels.WARN)
      end

      return
    end

    local out = vim.system({ "git", "-C", root, "show", ":0:" .. rel }, { text = true }):wait()

    if out.code ~= 0 then
      vim.notify(("sidebar: %s is not in the index, nothing to diff against"):format(rel), vim.log.levels.WARN)

      return
    end

    local lines = vim.split(out.stdout or "", "\n")

    -- `git show` ends with a newline, which split turns into a trailing empty
    -- line the file itself does not have -- one phantom deleted line in the
    -- diff otherwise.
    if lines[#lines] == "" then
      table.remove(lines)
    end

    local buf = vim.api.nvim_win_get_buf(win)
    local base = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(base, 0, -1, false, lines)

    -- The name has to be unique or `set_name` fails, and a nameless pane is a
    -- pane `diff_close` cannot find again. The buffer number is at hand and is
    -- unique by construction.
    pcall(vim.api.nvim_buf_set_name, base, ("sidebar-diff://%d/%s"):format(base, rel))
    vim.bo[base].filetype = vim.bo[buf].filetype
    vim.bo[base].bufhidden = "wipe"
    vim.bo[base].modifiable = false

    -- Closing the left pane has to take the diff mode of the right one with
    -- it, or the file stays folded and coloured as half a diff.
    vim.api.nvim_create_autocmd({ "BufWipeout", "BufHidden" }, {
      buffer = base,
      once = true,
      callback = function()
        if vim.api.nvim_win_is_valid(win) then
          vim.wo[win].diff = false
        end
      end,
    })

    vim.api.nvim_win_call(win, function()
      vim.cmd("aboveleft vsplit")
      vim.api.nvim_win_set_buf(0, base)
      vim.cmd("diffthis")
    end)

    vim.api.nvim_win_call(win, function()
      vim.cmd("diffthis")
    end)
  end

  vim.schedule(attempt)
end

--- Put the sidebar back at its width.
---
--- The layout asks for it already; this is the second line of defence. snacks
--- adopts any later resize of the split into the layout (layout.lua, the
--- WinResized handler), so one stray drag of the border -- or a width that
--- never arrived -- would be remembered rather than corrected.
---@param p snacks.Picker
---@param width integer
local function enforce_width(p, width)
  local root = p.layout and p.layout.root
  local win = root and root.win

  if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_width(win) ~= width then
    vim.api.nvim_win_set_width(win, width)
  end
end

--- What a picker panel does the moment it is on screen: hold its width, and
--- raise the bar above it.
---
--- Shared, because the explorer has more than one door -- snacks opens it by
--- itself on `nvim .` -- and a panel without its bar is a sidebar with no way
--- back to the other two.
---@param name string
local function on_show(name)
  return function(p)
    enforce_width(p, M.width)

    -- Scheduled: on_show runs while snacks is still building its layout, and a
    -- new split in the middle of that is a window it did not expect.
    vim.schedule(function()
      local root = p.layout and p.layout.root and p.layout.root.win

      bar_open(root, name)
      bar_follow(root)
    end)
  end
end

---@param source string
---@param name string the panel this picker is, for the icon row
local function picker_panel(source, opts, name)
  return {
    is_open = function()
      return picker(source) ~= nil
    end,
    is_focused = function()
      local p = picker(source)

      return p ~= nil and p:is_focused()
    end,
    focus = function()
      local p = picker(source)

      if p then
        p:focus()
      end
    end,
    close = function()
      local p = picker(source)

      if p then
        p:close()
      end
    end,
    open = function()
      local o = opts()

      o.on_show = o.on_show or on_show(name)

      Snacks.picker.pick(source, o)
    end,
  }
end

--- The explorer, as a snacks SOURCE config rather than as arguments to one
--- call.
---
--- The explorer has more than one door: snacks opens it by itself when Neovim
--- starts on a directory (`nvim .`), and LazyVim has <leader>fe. Configuring
--- the source is what makes every one of them land on the same panel, icon row
--- included -- passing the options per call only decorates the door we own.
function M.explorer_source()
  return {
    layout = layout(false, M.width),
    win = wins("explorer"),
    on_show = on_show("explorer"),
  }
end

local panels = {
  explorer = picker_panel("explorer", M.explorer_source, "explorer"),

  git = picker_panel("git_status", function()
    local win = wins("git")

    -- `<cr>` opens the diff, so the plain file needs a key of its own.
    win.list.keys["o"] = "jump"

    return {
      -- The explorer defaults; git_status is a plain picker and has neither.
      -- Without them the panel closes as soon as a file is opened or the
      -- cursor moves to the editor, and the sidebar is gone after one click.
      auto_close = false,
      jump = { close = false },
      -- A plain picker starts with the cursor in the input, which this panel
      -- keeps hidden. The list is where the cursor belongs anyway.
      focus = "list",
      -- The list runs each of these in order: drop the previous diff, open the
      -- file in the editor window, diff it against the index.
      confirm = { "sidebar_diff_close", "jump", "sidebar_diff" },
      actions = {
        sidebar_diff_close = diff_close,
        sidebar_diff = diff_open,
      },
      layout = layout("main", M.width),
      win = win,
    }
  end, "git"),

  search = {
    is_open = function()
      return require("grug-far").is_instance_open(INSTANCE)
    end,
    is_focused = function()
      return search_win ~= nil
        and vim.api.nvim_win_is_valid(search_win)
        and vim.api.nvim_get_current_win() == search_win
    end,
    focus = function()
      if search_win and vim.api.nvim_win_is_valid(search_win) then
        vim.api.nvim_set_current_win(search_win)
      end
    end,
    close = function()
      -- grug-far parks the cursor in its search field, in INSERT mode. Closing
      -- the window from there leaves the mode behind, and the next keys typed
      -- land as text in whatever file the editor shows.
      vim.cmd("stopinsert")

      -- hide, not kill: the search text and the results survive, the way the
      -- VSCode panel keeps them when you switch away from it.
      require("grug-far").hide_instance(INSTANCE)
    end,
    open = function()
      local grug = require("grug-far")

      if grug.has_instance(INSTANCE) then
        grug.get_instance(INSTANCE):open()
      else
        grug.open({
          instanceName = INSTANCE,
          windowCreationCommand = "topleft vsplit",
          prefills = { paths = LazyVim.root() },
        })
      end

      search_win = vim.api.nvim_get_current_win()

      vim.api.nvim_win_set_width(search_win, M.width_search)
      vim.wo[search_win].winfixwidth = true
      bar_open(search_win, "search")
      bar_follow(search_win)
    end,
  },
}

--- The window a panel lives in, or nil when it is not on screen.
---@param name string
local function panel_win(name)
  local win

  if name == "search" then
    win = search_win
  else
    local p = picker(name == "git" and "git_status" or "explorer")

    win = p and p.layout and p.layout.root and p.layout.root.win
  end

  return win and vim.api.nvim_win_is_valid(win) and win or nil
end

--- Keep the bar matched to the panel through a resize.
---
--- Two different jobs, and the second one is why this is not simply a redraw:
--- the buttons have to follow the width, AND the bar has to come back. snacks
--- rebuilds the root window of a split layout when the editor is resized,
--- which takes our WinClosed watcher with it and leaves the panel bare.
vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
  group = vim.api.nvim_create_augroup("clowk_sidebar_bar", { clear = true }),
  callback = function()
    if bar_active == "" then
      return
    end

    if bar_win and vim.api.nvim_win_is_valid(bar_win) then
      bar_render(bar_active)

      return
    end

    vim.schedule(function()
      local win = panel_win(bar_active)

      if win then
        bar_open(win, bar_active)
        bar_follow(win)
      end
    end)
  end,
})

--- Show one panel, closing whatever else is docked.
---@param name string
function M.open(name)
  local function raise()
    bar_close()

    M.current = name
    panels[name].open()
  end

  local closed = false

  for other, panel in pairs(panels) do
    if other ~= name and panel.is_open() then
      panel.close()
      closed = true
    end
  end

  -- A closed picker is not finished. Its layout keeps a WinResized handler
  -- alive for one more tick, and the resize caused by taking OUR window out of
  -- the same column reaches it after its list is already gone
  -- (`list.lua: attempt to index field 'picker'`). One tick of patience and
  -- the teardown is over.
  if closed then
    vim.schedule(raise)
  else
    raise()
  end
end

--- Toggle one panel, in three steps rather than two.
---
--- Closed        -> open it.
--- Open, elsewhere -> go to it. This is the step a plain toggle misses: after
---                  `<cr>` opens a diff the cursor is in the editor, and the
---                  key that means "the source control panel" should take you
---                  back to it, not take it away.
--- Open, focused -> close it.
---@param name string
function M.toggle(name)
  local panel = panels[name]

  if not panel.is_open() then
    M.open(name)

    return
  end

  if not panel.is_focused() then
    panel.focus()

    return
  end

  M.current = nil
  panel.close()
  bar_close()
end

return M
