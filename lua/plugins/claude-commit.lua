-- "Generate commit message" -- the sparkle button in VSCode's Source Control
-- panel -- with Claude as the engine.
--
-- <leader>gm, and it means the same thing in the two places you commit from:
--
--   * in a commit buffer it writes the message in, above git's comment block.
--     This is the one that matters: <leader>gg opens lazygit, `C` there opens
--     the commit editor, and snacks starts lazygit with `editPreset =
--     "nvim-remote"`, so that editor is not a nested Neovim -- it is a real
--     buffer in the Neovim you are already sitting in. Same for `git commit`
--     from a shell, once $EDITOR is nvim.
--   * anywhere else it opens a commit buffer of its own, already filled in, and
--     commits from there.
--
-- There is no plugin and no API key. The engine is the `claude` CLI already on
-- PATH -- the same binary and the same subscription as the sidebar on
-- cmd+option+b -- so a message costs nothing per call. The whole thing is
-- `git diff --cached` piped into `claude -p`.

--- The model, and how hard it is allowed to think.
---
--- Measured on this repo's own history, generating the message for an 11KB
--- diff: sonnet at low effort answers in ~5s, the same call at the default
--- effort takes ~30s for a message no better, and haiku manages to be both
--- slower (~16s) and worse -- it dropped the Conventional Commits prefix that
--- every subject in this repo carries.
local MODEL = "sonnet"
local EFFORT = "low"

--- Replaces Claude Code's own system prompt rather than appending to it, so
--- none of the coding-agent preamble is sent, read or paid for.
local SYSTEM_PROMPT = "You write git commit messages. You reply with the commit message and nothing else."

--- Belt and braces. The diff is already on stdin, so there is nothing for
--- Claude to go looking for, and a tool call here would only cost seconds.
local DISALLOWED_TOOLS = "Bash,Read,Write,Edit,Glob,Grep,WebFetch,WebSearch,Task,TodoWrite"

--- Diffs go whole up to this many lines, and truncated with a `--stat` summary
--- above them past it. A diff this size is already well beyond the point where
--- one paragraph can say anything specific about it; sending the rest only
--- makes the call slower.
local MAX_DIFF_LINES = 3000

--- How many recent subjects to send as the style reference.
---
--- This is the single highest-leverage part of the prompt. Without it the
--- messages come back in generic house style; with it they come back with this
--- repo's `feat(tmux):` prefixes, its casing and its habit of explaining the
--- rejected alternative. Nothing describes a project's commit conventions as
--- accurately as its own log.
local STYLE_SUBJECTS = 15

local NOTIFY_ID = "claude_commit"

local running = false

local function notify(msg, level, opts)
  vim.notify(
    msg,
    level or vim.log.levels.INFO,
    vim.tbl_extend("force", { title = "Claude commit", id = NOTIFY_ID }, opts or {})
  )
end

local function argv(base, extra)
  local out = vim.list_extend({}, base)

  return vim.list_extend(out, extra)
end

--- Ask git for something, synchronously.
---
--- These are all index and object-store reads that finish in single-digit
--- milliseconds, so none of them is worth an async callback. The one call that
--- IS slow -- claude -- is the one that gets one.
local function git_lines(base, args)
  local out = vim.fn.systemlist(argv(base, args))
  if vim.v.shell_error ~= 0 then
    return nil
  end

  return out
end

--- The `git` argv prefix to read this buffer's repository with.
---
--- A commit buffer is <git-dir>/COMMIT_EDITMSG, and a git dir is not a work
--- tree -- `git -C` there refuses to run at all ("this operation must be run in
--- a work tree"). `--git-dir` does run, and the three things needed here (the
--- staged diff, the recent subjects, HEAD when amending) all read from the
--- index and the object store, so not one of them wants a work tree.
---
--- It is also the only form that stays correct inside a linked worktree, where
--- the git dir lives under the main clone and no amount of walking up from the
--- file path would find the right one.
local function git_for(buf)
  if vim.bo[buf].filetype == "gitcommit" then
    local file = vim.api.nvim_buf_get_name(buf)
    if file ~= "" then
      return { "git", "--git-dir=" .. vim.fn.fnamemodify(file, ":p:h") }
    end
  end

  return { "git", "-C", LazyVim.root() }
end

--- What the message should describe.
---
--- The staged diff is the answer almost every time. It is empty in exactly one
--- case worth handling: `git commit --amend` with nothing new staged, where the
--- subject is HEAD's own diff. That case is only reachable from a commit
--- buffer, because git refuses to open an editor at all when there is nothing
--- to commit -- so an empty index there means an amend, and anywhere else it
--- means you have not staged yet.
---
--- `git diff HEAD` is deliberately not a fallback. It would describe unstaged
--- work that the commit is not going to contain, which is a worse outcome than
--- saying nothing.
local function subject_diff(git, in_commit_buffer)
  local staged = git_lines(git, { "diff", "--cached", "--no-color", "--no-ext-diff" })
  if staged and #staged > 0 then
    return staged, false
  end

  if in_commit_buffer then
    local head = git_lines(git, { "show", "HEAD", "--no-color", "--no-ext-diff", "--format=" })
    if head and #head > 0 then
      return head, true
    end
  end
end

local function clamp(git, diff, amending)
  if #diff <= MAX_DIFF_LINES then
    return diff
  end

  local args = amending and { "show", "HEAD", "--stat", "--format=" } or { "diff", "--cached", "--stat" }
  local kept = vim.list_extend({}, git_lines(git, args) or {})

  table.insert(kept, "")
  vim.list_extend(kept, vim.list_slice(diff, 1, MAX_DIFF_LINES))
  table.insert(kept, "")
  table.insert(kept, ("[... %d further lines omitted, see the summary above ...]"):format(#diff - MAX_DIFF_LINES))

  return kept
end

local function build_prompt(git, amending)
  -- When amending, HEAD is the message being replaced. Offering it back as a
  -- style example invites Claude to simply hand it over again.
  local log = { "log", "-n", tostring(STYLE_SUBJECTS), "--pretty=format:%s" }
  if amending then
    table.insert(log, "--skip=1")
  end

  local parts = { "Write a commit message for the diff on stdin." }

  local subjects = git_lines(git, log)
  if subjects and #subjects > 0 then
    table.insert(parts, "")
    table.insert(parts, "Every subject this repo has used recently, newest first:")
    table.insert(parts, table.concat(subjects, "\n"))
    table.insert(parts, "")
    -- Naming the convention is not enough on its own. Told only to "match the
    -- style", Claude reliably reproduces the tone and just as reliably drops
    -- the `feat(scope):` prefix when there are few examples to generalise from,
    -- so the prefix gets its own sentence and its own instruction.
    table.insert(
      parts,
      "Those subjects define the convention and override any default you would "
        .. "otherwise reach for. If they carry a type and scope prefix, yours "
        .. "carries one too, drawn from the same vocabulary."
    )
  end

  table.insert(parts, "")
  table.insert(
    parts,
    "Rules: subject <=72 chars, imperative mood. Then a blank line and a body "
      .. "wrapped at 72 explaining WHY, but only if the subject is not "
      .. "self-explanatory. No trailers, no attribution, no markdown fences."
  )

  return table.concat(parts, "\n")
end

--- Claude is told not to fence the message and does not, but a stray ``` on the
--- first line would be committed verbatim, so one is stripped if it appears.
local function clean(out)
  local text = vim.trim(out or "")
  text = text:gsub("^```%w*\n", ""):gsub("\n```$", "")

  return vim.trim(text)
end

local function generate(git, in_commit_buffer, on_message)
  if vim.fn.executable("claude") == 0 then
    return notify("claude is not on PATH", vim.log.levels.ERROR)
  end

  if running then
    return notify("already writing one", vim.log.levels.WARN)
  end

  local diff, amending = subject_diff(git, in_commit_buffer)
  if not diff then
    return notify("nothing staged to describe", vim.log.levels.WARN)
  end

  running = true
  notify(amending and "rewriting the message for HEAD…" or "writing the commit message…", nil, { timeout = false })

  local cmd = {
    "claude",
    "-p",
    "--model",
    MODEL,
    "--effort",
    EFFORT,
    -- Drops CLAUDE.md, skills, hooks, plugins and MCP servers for this one
    -- call. Mostly that is latency -- the MCP servers alone add seconds to
    -- startup -- but it also means the message does not change depending on
    -- which machine, or which project's instructions, it was generated from.
    -- Authentication is untouched by it, unlike --bare, which insists on an
    -- ANTHROPIC_API_KEY and would break subscription auth outright.
    "--safe-mode",
    -- One-shot generation has no business showing up in `claude --resume`.
    "--no-session-persistence",
    "--system-prompt",
    SYSTEM_PROMPT,
    "--disallowed-tools",
    DISALLOWED_TOOLS,
    -- `--` is load-bearing, not decoration. --disallowed-tools is variadic --
    -- it takes a SPACE-separated list -- so without a terminator it swallows
    -- the prompt as one more tool name. Claude Code then finds no positional
    -- prompt, falls back to reading stdin as the prompt, and answers from the
    -- bare diff: a plausible-looking message that silently ignored every
    -- instruction above, style examples included. It fails by getting quietly
    -- worse rather than by erroring, which is exactly the kind of bug that
    -- survives a casual test.
    "--",
    -- The prompt itself is a positional argument; -p is only a flag.
    build_prompt(git, amending),
  }

  local stdin = table.concat(clamp(git, diff, amending), "\n")

  -- vim.system throws rather than calling back when the spawn itself fails, and
  -- an uncaught one here would leave `running` true for the rest of the session
  -- -- every later press answering "already writing one" for a call that is not.
  local ok, err = pcall(vim.system, cmd, { stdin = stdin, text = true }, function(res)
    vim.schedule(function()
      running = false

      if res.code ~= 0 then
        return notify("claude failed:\n" .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
      end

      local message = clean(res.stdout)
      if message == "" then
        return notify("claude returned nothing", vim.log.levels.ERROR)
      end

      notify(amending and "message rewritten" or "message written", nil, { timeout = 1500 })
      on_message(message)
    end)
  end)

  if not ok then
    running = false
    notify("could not run claude:\n" .. tostring(err), vim.log.levels.ERROR)
  end
end

--- Put the message above git's comment block, leaving the block itself alone.
---
--- Those comments are not decoration. `git commit --verbose` puts the entire
--- diff underneath them, and git strips everything commented out on save.
--- Replacing the buffer wholesale would take the status listing and the diff
--- with it, and on a verbose commit that is most of the buffer.
local function fill_commit_buffer(buf, git, message)
  -- core.commentChar can be set to something other than #, and to "auto",
  -- where git picks a character no line starts with. Nothing but the literal
  -- single-character setting is worth honouring -- on "auto" the answer is
  -- unknowable from here, and # is what git picks in practice.
  local configured = (git_lines(git, { "config", "--get", "core.commentChar" }) or {})[1]
  local char = (configured and #configured == 1) and configured or "#"

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local body_end = #lines
  for i, line in ipairs(lines) do
    if line:sub(1, 1) == char then
      body_end = i - 1
      break
    end
  end

  local new = vim.split(message, "\n")
  table.insert(new, "")

  vim.api.nvim_buf_set_lines(buf, 0, body_end, false, new)
  pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
end

local function commit(root, message)
  vim.system({ "git", "-C", root, "commit", "-F", "-" }, { stdin = message, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        return notify("git commit failed:\n" .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
      end

      notify(vim.trim(res.stdout or ""))
      pcall(function()
        require("gitsigns").refresh()
      end)
    end)
  end)
end

--- The commit buffer for when there is not one yet: <leader>gm from an ordinary
--- file, without going through lazygit first.
---
--- A scratch buffer rather than git's own COMMIT_EDITMSG, because reaching that
--- one requires `git commit` to already be running and blocked on an editor.
--- `git commit -F -` at the end does the same job from the other direction: the
--- message goes in on stdin, so nothing is written to disk and there is nothing
--- to clean up if you back out.
local function open_commit_float(root, message)
  local lines = vim.split(message, "\n")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "gitcommit"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.min(80, math.floor(vim.o.columns * 0.8))
  local height = math.max(math.min(#lines + 2, math.floor(vim.o.lines * 0.6)), 5)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " git commit ",
    title_pos = "center",
    footer = " <C-s> commit  ·  q discard ",
    footer_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  -- The 72-column rule the prompt asks for, made visible while you edit.
  vim.wo[win].colorcolumn = "73"

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close, { buffer = buf, desc = "Discard commit" })
  vim.keymap.set({ "n", "i" }, "<C-s>", function()
    local edited = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
    if edited == "" then
      return notify("empty message, nothing committed", vim.log.levels.WARN)
    end

    vim.cmd("stopinsert")
    close()
    commit(root, edited)
  end, { buffer = buf, desc = "Commit" })
end

local function run()
  local buf = vim.api.nvim_get_current_buf()
  local in_commit_buffer = vim.bo[buf].filetype == "gitcommit"
  local git = git_for(buf)

  if not git_lines(git, { "rev-parse", "--git-dir" }) then
    return notify("not a git repository", vim.log.levels.WARN)
  end

  generate(git, in_commit_buffer, function(message)
    if in_commit_buffer then
      -- The buffer can be gone by now: five seconds is long enough to give up
      -- and close the commit editor, and writing into a dead buffer throws.
      if vim.api.nvim_buf_is_valid(buf) then
        fill_commit_buffer(buf, git, message)
      end

      return
    end

    open_commit_float(LazyVim.root(), message)
  end)
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gm", run, desc = "Commit message (Claude)" },
    },
    init = function()
      vim.api.nvim_create_user_command("ClaudeCommit", run, { desc = "Commit message (Claude)" })

      -- The same key again, buffer-local, for the commit editor itself.
      --
      -- Declaring it here as well as in `keys` above is not redundant. The
      -- `keys` entry is a lazy.nvim stub whose job is to load snacks.nvim on
      -- the first press; a commit buffer that arrives through lazygit's
      -- `nvim --remote` lands in a Neovim where that stub may still be all
      -- there is. A real buffer-local mapping answers on the first press
      -- either way.
      --
      -- Normal mode is the only mode it needs: nothing here starts a commit
      -- buffer in insert, so the cursor is already where the key works.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "gitcommit",
        callback = function(ev)
          vim.keymap.set("n", "<leader>gm", run, { buffer = ev.buf, desc = "Commit message (Claude)" })
        end,
      })
    end,
  },
}
