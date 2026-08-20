-- Audio files, played inside Neovim.
--
-- Neovim does not know what a .mp3 is: opening one reads the raw bytes into a
-- buffer and paints the screen with binary garbage. snacks.image solves the
-- same problem for pictures (see lua/plugins/markdown.lua) by taking over
-- `BufReadCmd` -- the autocmd that REPLACES the read of a file -- and drawing
-- something else instead. This module does that for sound:
--
--     󰋅  song.mp3
--     mp3 · 44.1 kHz · stereo · 128 kbps · 3.4 MB
--
--        ▄▄▄█▄▄▄▄           ▄▄▄▄▄▄▄        <- the waveform IS the seek bar:
--     ▄███████████▄      ▄███████████▄         the played part is highlighted,
--   ▄███████████████▄  ▄███████████████▄       and a click seeks to that point
--  ███████████████████████████████████████
--   ▀███████████████▀  ▀███████████████▀
--     ▀███████████▀      ▀███████████▀
--        ▀▀▀█▀▀▀▀           ▀▀▀▀▀▀▀
--
--     ▶  01:23 / 03:45   vol 80
--
-- EXTERNAL TOOLS. All optional; each missing one costs exactly one feature.
--
--   ffplay   playback WITH seek.  brew install ffmpeg
--   afplay   macOS built-in, used when ffplay is absent. It plays, but it
--            cannot seek: afplay has no start-offset flag, and seeking here is
--            implemented by restarting the player at an offset.
--   ffmpeg   draws the waveform. Without it the seek bar is a flat line.
--   ffprobe  duration + the format line. `afinfo` (macOS) covers the duration.
--
-- WHY THE WAVEFORM NEEDS RECTIFYING. Asking ffmpeg for a low sample rate is the
-- obvious way to get ~one value per screen column, and it returns a flat line:
-- resampling a 440 Hz tone down to 100 Hz averages the positive and the
-- negative half of every cycle into roughly zero. Rectifying FIRST
-- (`aeval=abs(val(0))`) and resampling after averages |x| instead, which is the
-- envelope we actually want to draw.

local M = {}

local uv = vim.uv or vim.loop

--- Extensions this module takes over. The first group is what afplay (CoreAudio)
--- can play on its own; ogg/opus/wma need ffplay.
M.formats = { "mp3", "wav", "m4a", "aac", "aif", "aiff", "caf", "flac", "ogg", "oga", "opus", "wma" }

M.config = {
  -- Rows above the centre line. The waveform is mirrored, so the block is
  -- twice this high.
  wave_rows = 4,
  -- How many envelope points to ask ffmpeg for. Anything above the window
  -- width is detail nobody sees, so this only has to beat a wide screen.
  wave_samples = 1200,
  -- Left margin of every drawn line.
  pad = "  ",
  seek_small = 5,
  seek_big = 30,
  volume = 80,
  volume_step = 10,
  -- How often the played/remaining split is redrawn while playing.
  tick_ms = 100,
}

local NS = vim.api.nvim_create_namespace("clowk_audio")

---@type table<integer, table> buffer -> player
local players = {}

local function have(bin)
  return vim.fn.executable(bin) == 1
end

local function fmt_time(seconds)
  if not seconds or seconds < 0 then
    return "--:--"
  end

  local total = math.floor(seconds)
  local h, m, s = math.floor(total / 3600), math.floor(total / 60) % 60, total % 60

  if h > 0 then
    return string.format("%d:%02d:%02d", h, m, s)
  end

  return string.format("%02d:%02d", m, s)
end

local function fmt_size(bytes)
  if not bytes or bytes <= 0 then
    return nil
  end

  local units = { "B", "KB", "MB", "GB" }
  local i = 1

  while bytes >= 1024 and i < #units do
    bytes, i = bytes / 1024, i + 1
  end

  return string.format(i == 1 and "%d %s" or "%.1f %s", bytes, units[i])
end

-- Playback -------------------------------------------------------------------

--- Kill the running player, if any. `gen` guards the exit callback: a process we
--- killed ourselves must not be mistaken for a track that reached its end.
---
--- The SIGCONT is not redundant. A paused player is SIGSTOPped, and a stopped
--- process never SEES the SIGTERM -- the signal waits until it runs again, so
--- closing a paused buffer would leave ffplay frozen forever. It has to be
--- woken up to die.
---
--- `paused` is left alone on purpose: only the caller knows whether this is a
--- stop (forget the position) or a freeze (keep it).
local function kill(p)
  if p.proc then
    p.gen = p.gen + 1
    pcall(function()
      p.proc:kill("sigterm")
      p.proc:kill("sigcont")
    end)
    p.proc = nil
  end

  p.playing = false
end

local function render(p) end -- forward declaration, defined below

local function tick(p)
  if not p.timer then
    p.timer = uv.new_timer()
  end

  p.timer:stop()

  if p.playing and not p.paused then
    p.timer:start(
      M.config.tick_ms,
      M.config.tick_ms,
      vim.schedule_wrap(function()
        if vim.api.nvim_buf_is_valid(p.buf) then
          render(p)
        else
          kill(p)
          p.timer:stop()
        end
      end)
    )
  end
end

--- Where the playhead is, in seconds. While a process runs the position is
--- wall-clock time since it started, plus the offset it started at -- neither
--- afplay nor `ffplay -nodisp` reports its own progress.
local function position(p)
  if p.playing and not p.paused then
    return p.pos + (uv.hrtime() - p.started) / 1e9
  end

  return p.pos
end

--- Freeze every other player. Two tracks over the same speakers is never what
--- was meant, and the other buffer keeps its position, so it resumes where it
--- was left.
local function pause_others(p)
  for _, other in pairs(players) do
    if other ~= p and other.playing then
      other.pos = position(other)
      kill(other)
      other.paused = true

      if other.timer then
        other.timer:stop()
      end

      render(other)
    end
  end
end

local function play(p, offset)
  kill(p)
  pause_others(p)

  offset = math.max(0, offset or 0)

  if p.duration and offset >= p.duration - 0.05 then
    offset = 0
  end

  if not p.backend then
    return vim.notify("No audio player found. `brew install ffmpeg` for ffplay.", vim.log.levels.WARN)
  end

  local cmd
  if p.backend == "ffplay" then
    -- stylua: ignore
    cmd = {
      "ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet",
      "-volume", tostring(p.volume), "-ss", string.format("%.3f", offset), p.file,
    }
  else
    cmd = { "afplay", "-v", string.format("%.2f", p.volume / 100), p.file }
  end

  p.pos = offset
  p.started = uv.hrtime()
  p.playing = true
  p.paused = false

  local gen = p.gen

  p.proc = vim.system(cmd, {}, function(res)
    vim.schedule(function()
      -- A stale exit: this process was replaced by a seek, a stop or a new
      -- track. The player it belonged to is already gone.
      if gen ~= p.gen then
        return
      end

      local ended_at = position(p)

      p.proc = nil
      p.playing = false
      p.paused = false
      p.pos = p.duration or ended_at

      if res.code ~= 0 and res.code ~= 143 then
        vim.notify(("%s exited with %d\n%s"):format(p.backend, res.code, res.stderr or ""), vim.log.levels.ERROR)
      end

      if p.loop then
        return play(p, 0)
      end

      tick(p)
      render(p)
    end)
  end)

  tick(p)
  render(p)
end

--- Three states, not two: playing, frozen with the process still alive, and
--- stopped -- which includes "paused, then seeked", where the frozen process
--- was dropped because it cannot be continued anywhere but where it stood.
local function toggle(p)
  if not p.playing then
    p.paused = false

    return play(p, p.pos)
  end

  -- afplay and ffplay have no pause command, so pausing is SIGSTOP: the
  -- process freezes mid-buffer and SIGCONT picks the sound up where it was.
  if p.paused then
    p.started = uv.hrtime()
    p.paused = false
    pcall(function()
      p.proc:kill("sigcont")
    end)
  else
    p.pos = position(p)
    p.paused = true
    pcall(function()
      p.proc:kill("sigstop")
    end)
  end

  tick(p)
  render(p)
end

local function stop(p)
  kill(p)
  p.paused = false
  p.pos = 0
  tick(p)
  render(p)
end

local function seek(p, to)
  if p.duration then
    to = math.min(to, p.duration)
  end

  to = math.max(0, to)

  if p.playing then
    if p.backend ~= "ffplay" then
      return vim.notify("afplay cannot seek. `brew install ffmpeg` for ffplay.", vim.log.levels.WARN)
    end

    -- Frozen: drop the process rather than restart it. Seeking a paused track
    -- must not make a sound, so the new position waits for the next play.
    if p.paused then
      kill(p)
      p.pos = to

      return render(p)
    end

    return play(p, to)
  end

  p.pos = to
  render(p)
end

local function set_volume(p, vol)
  p.volume = math.max(0, math.min(100, vol))
  p.muted = p.volume == 0

  -- Both backends take the volume once, at spawn time. Changing it while a
  -- track plays means restarting the process where the playhead is -- free on
  -- ffplay, impossible on afplay (no seek), so there it only affects the next
  -- play.
  if p.playing and p.backend == "ffplay" then
    return play(p, position(p))
  end

  render(p)
end

-- Waveform -------------------------------------------------------------------

--- s16le mono bytes -> normalised envelope in [0, 1].
local function decode(data)
  local byte, peaks, max = string.byte, {}, 1

  for i = 1, #data - 1, 2 do
    local lo, hi = byte(data, i, i + 1)
    local v = hi * 256 + lo

    if v >= 32768 then
      v = 65536 - v
    end

    peaks[#peaks + 1] = v

    if v > max then
      max = v
    end
  end

  for i, v in ipairs(peaks) do
    peaks[i] = v / max
  end

  return peaks
end

local function load_wave(p)
  if not have("ffmpeg") then
    return
  end

  -- One envelope point per `1/rate` seconds. Tying the rate to the duration
  -- keeps a 3-minute song and a 2-hour podcast equally cheap to decode.
  local rate = 50

  if p.duration and p.duration > 1 then
    rate = math.max(2, math.min(200, math.floor(M.config.wave_samples / p.duration)))
  end

  -- stylua: ignore
  local cmd = {
    "ffmpeg", "-v", "error", "-nostdin", "-i", p.file,
    "-ac", "1", "-af", "aeval=abs(val(0)):c=same", "-ar", tostring(rate), "-f", "s16le", "-",
  }

  vim.system(
    cmd,
    { text = false },
    vim.schedule_wrap(function(res)
      if res.code == 0 and res.stdout and #res.stdout >= 4 then
        p.peaks, p.columns = decode(res.stdout), nil
        render(p)
      end
    end)
  )
end

-- Metadata -------------------------------------------------------------------

local function load_info(p)
  local stat = uv.fs_stat(p.file)
  p.size = stat and stat.size or nil

  if have("ffprobe") then
    -- stylua: ignore
    local cmd = {
      "ffprobe", "-v", "error", "-select_streams", "a:0",
      "-show_entries", "stream=codec_name,sample_rate,channels:format=duration,bit_rate",
      "-of", "json", p.file,
    }

    return vim.system(
      cmd,
      { text = true },
      vim.schedule_wrap(function(res)
        local ok, probe = pcall(vim.json.decode, res.stdout or "")

        if ok and probe then
          local stream = (probe.streams or {})[1] or {}
          local format = probe.format or {}

          p.codec = stream.codec_name
          p.rate = tonumber(stream.sample_rate)
          p.channels = tonumber(stream.channels)
          p.bitrate = tonumber(format.bit_rate)
          p.duration = tonumber(format.duration)
        end

        load_wave(p)
        render(p)
      end)
    )
  end

  if have("afinfo") then
    return vim.system(
      { "afinfo", p.file },
      { text = true },
      vim.schedule_wrap(function(res)
        p.duration = tonumber((res.stdout or ""):match("estimated duration:%s*([%d%.]+)"))
        load_wave(p)
        render(p)
      end)
    )
  end

  load_wave(p)
end

-- Drawing --------------------------------------------------------------------

local FULL, HALF_UP, HALF_DOWN = "█", "▀", "▄"

--- One cell of the mirrored waveform, `distance` rows away from the centre
--- line. Half blocks give half-cell precision with two characters every font
--- has -- the eighth blocks (▁▂▃) only fill from the bottom, which is wrong
--- for the half of the waveform that hangs downwards.
local function cell(level, rows, distance, upwards)
  local left = level * rows - (distance - 1)

  if left >= 1 then
    return FULL
  elseif left >= 0.5 then
    return upwards and HALF_DOWN or HALF_UP
  end

  return " "
end

--- The peak of every sample behind a screen column. A peak, not an average: an
--- average of an envelope flattens exactly the transients that make a waveform
--- readable. Only the window width changes it, so it survives a tick.
local function columns(p, width)
  if p.columns and p.columns_width == width then
    return p.columns
  end

  local out, total = {}, #p.peaks

  for c = 1, width do
    local from = math.floor((c - 1) / width * total) + 1
    local to = math.min(total, math.max(from, math.floor(c / width * total)))
    local peak = 0

    for i = from, to do
      peak = math.max(peak, p.peaks[i])
    end

    out[c] = peak
  end

  p.columns, p.columns_width = out, width

  return out
end

--- The waveform rows, each split at the playhead so the played part can carry
--- its own highlight. Byte offsets, not columns: a block is 3 bytes and a
--- space is 1, so the split has to be measured while the row is built.
---@return string[] rows, integer[] split byte offset per row
local function wave_rows(p, width, progress)
  local rows, splits = {}, {}
  local at = math.max(0, math.min(width, math.floor(progress * width + 0.5)))

  if not p.peaks then
    -- No ffmpeg: a plain seek bar. Still clickable, still shows the progress.
    local played = ("━"):rep(at)

    rows[1] = played .. ("─"):rep(width - at)
    splits[1] = #played

    return rows, splits
  end

  local half = M.config.wave_rows
  local peaks = columns(p, width)

  for r = 1, half * 2 do
    local upwards = r <= half
    local distance = upwards and (half - r + 1) or (r - half)
    local row, split = {}, 0

    for c = 1, width do
      local char = cell(peaks[c], half, distance, upwards)

      row[c] = char

      if c <= at then
        split = split + #char
      end
    end

    rows[r] = table.concat(row)
    splits[r] = split
  end

  return rows, splits
end

local function icon_line(p)
  local parts = {}

  if p.codec then
    parts[#parts + 1] = p.codec
  end

  if p.rate then
    parts[#parts + 1] = ("%.1f kHz"):format(p.rate / 1000)
  end

  if p.channels then
    parts[#parts + 1] = p.channels == 1 and "mono" or (p.channels == 2 and "stereo" or p.channels .. " ch")
  end

  if p.bitrate then
    parts[#parts + 1] = ("%d kbps"):format(math.floor(p.bitrate / 1000))
  end

  parts[#parts + 1] = fmt_size(p.size)

  return table.concat(parts, " · ")
end

--- Redraw the whole buffer. Cheap enough to do on every tick: a dozen short
--- strings, and the highlights have to be recomputed each time anyway.
function render(p)
  local buf = p.buf

  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local win = vim.fn.bufwinid(buf)
  local width = win ~= -1 and vim.api.nvim_win_get_width(win) or 80
  local pad = M.config.pad

  width = math.max(20, width - #pad * 2 - 1)

  local at = position(p)
  local progress = (p.duration and p.duration > 0) and math.min(1, at / p.duration) or 0
  local rows, splits = wave_rows(p, width, progress)

  local state = p.paused and "" or (p.playing and "" or "󰓛")
  local status = ("%s  %s / %s   vol %d%s%s"):format(
    state,
    fmt_time(at),
    fmt_time(p.duration),
    p.volume,
    p.loop and "   󰑖 repeat" or "",
    p.backend and "" or "   (no player found)"
  )

  local lines = { "", pad .. "󰋅  " .. vim.fn.fnamemodify(p.file, ":t"), pad .. icon_line(p), "" }
  local first_wave = #lines + 1

  for _, row in ipairs(rows) do
    lines[#lines + 1] = pad .. row
  end

  local keys = ("<space> play/pause   h l  ±%ds   H L  ±%ds   click  seek"):format(
    M.config.seek_small,
    M.config.seek_big
  )

  vim.list_extend(lines, {
    "",
    pad .. status,
    "",
    pad .. keys,
    pad .. "0 restart   s stop   - = volume   m mute   r repeat   q close",
  })

  -- Only the lines that actually changed are written. While a track plays this
  -- runs ten times a second, and rewriting the whole buffer that often fires
  -- every TextChanged in the editor for a clock that moved one second.
  vim.bo[buf].modifiable = true

  if not p.lines or #p.lines ~= #lines then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    for i, line in ipairs(lines) do
      if p.lines[i] ~= line then
        vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { line })
      end
    end
  end

  p.lines = lines

  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)

  local function hl(row, col, end_col, group)
    pcall(vim.api.nvim_buf_set_extmark, buf, NS, row, col, { end_col = end_col, hl_group = group })
  end

  --- Whole line, by its 0-based row.
  local function hl_line(row, group)
    hl(row, 0, #lines[row + 1], group)
  end

  hl_line(1, "ClowkAudioTitle")
  hl_line(2, "ClowkAudioInfo")

  for i, row in ipairs(rows) do
    local line = first_wave + i - 2
    local from = #pad

    hl(line, from, from + splits[i], "ClowkAudioPlayed")
    hl(line, from + splits[i], from + #row, "ClowkAudioWave")
  end

  hl_line(#lines - 4, "ClowkAudioStatus")
  hl_line(#lines - 2, "ClowkAudioKeys")
  hl_line(#lines - 1, "ClowkAudioKeys")

  -- The playhead column, remembered so a mouse click can be turned back into
  -- a time without measuring the string again.
  p.wave_col = #pad
  p.wave_width = width
  p.wave_line = first_wave
  p.wave_last = first_wave + #rows - 1
end

-- Buffer ---------------------------------------------------------------------

--- All buffer-local. `<space>` is the leader key everywhere else, so inside a
--- player buffer the leader is shadowed -- `p` and `<cr>` toggle too, for when
--- muscle memory wants the leader back.
local function keymaps(p)
  local buf = p.buf
  local cfg = M.config

  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = "Audio: " .. desc })
  end

  map("<space>", function()
    toggle(p)
  end, "play/pause")
  map("<cr>", function()
    toggle(p)
  end, "play/pause")
  map("p", function()
    toggle(p)
  end, "play/pause")
  map("s", function()
    stop(p)
  end, "stop")
  map("0", function()
    if p.playing then
      play(p, 0)
    else
      seek(p, 0)
    end
  end, "restart")

  map("l", function()
    seek(p, position(p) + cfg.seek_small)
  end, "forward")
  map("<right>", function()
    seek(p, position(p) + cfg.seek_small)
  end, "forward")
  map("h", function()
    seek(p, position(p) - cfg.seek_small)
  end, "back")
  map("<left>", function()
    seek(p, position(p) - cfg.seek_small)
  end, "back")
  map("L", function()
    seek(p, position(p) + cfg.seek_big)
  end, "forward 30s")
  map("H", function()
    seek(p, position(p) - cfg.seek_big)
  end, "back 30s")

  map("=", function()
    set_volume(p, p.volume + cfg.volume_step)
  end, "volume up")
  map("+", function()
    set_volume(p, p.volume + cfg.volume_step)
  end, "volume up")
  map("-", function()
    set_volume(p, p.volume - cfg.volume_step)
  end, "volume down")
  map("m", function()
    if p.muted then
      return set_volume(p, p.unmuted or cfg.volume)
    end

    p.unmuted = p.volume
    set_volume(p, 0)
  end, "mute")

  map("r", function()
    p.loop = not p.loop
    render(p)
  end, "repeat")
  map("q", function()
    stop(p)
    vim.api.nvim_buf_delete(buf, { force = true })
  end, "close")

  -- Click anywhere on the waveform to seek there.
  map("<leftrelease>", function()
    local mouse = vim.fn.getmousepos()

    if mouse.winid ~= vim.fn.bufwinid(buf) then
      return
    end

    if mouse.line < p.wave_line or mouse.line > p.wave_last or not p.duration then
      return
    end

    local col = mouse.wincol - p.wave_col - 1

    seek(p, math.max(0, math.min(1, col / p.wave_width)) * p.duration)
  end, "seek to click")
end

--- Take the buffer over: the bytes are never read, the player is drawn instead.
function M.open(buf)
  local file = vim.api.nvim_buf_get_name(buf)

  if players[buf] then
    kill(players[buf])
  end

  local p = {
    buf = buf,
    file = file,
    gen = 0,
    pos = 0,
    playing = false,
    paused = false,
    loop = false,
    volume = M.config.volume,
    backend = have("ffplay") and "ffplay" or (have("afplay") and "afplay" or nil),
  }

  players[buf] = p

  vim.bo[buf].filetype = "audio"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  local function window_options()
    local win = vim.fn.bufwinid(buf)

    if win ~= -1 then
      -- stylua: ignore
      for opt, value in pairs({
        number = false, relativenumber = false, cursorline = false, cursorcolumn = false,
        signcolumn = "no", foldcolumn = "0", list = false, spell = false, wrap = false, statuscolumn = "",
      }) do
        vim.api.nvim_set_option_value(opt, value, { win = win, scope = "local" })
      end
    end
  end

  local group = vim.api.nvim_create_augroup("clowk_audio_" .. buf, { clear = true })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    group = group,
    buffer = buf,
    callback = window_options,
  })

  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
    group = group,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) then
        render(p)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    buffer = buf,
    callback = function()
      kill(p)

      if p.timer then
        p.timer:stop()
        p.timer:close()
        p.timer = nil
      end

      players[buf] = nil

      vim.schedule(function()
        pcall(vim.api.nvim_del_augroup_by_id, group)
      end)
    end,
  })

  keymaps(p)
  window_options()
  render(p)
  load_info(p)

  return p
end

function M.setup()
  if M.did_setup then
    return
  end

  M.did_setup = true

  vim.api.nvim_set_hl(0, "ClowkAudioTitle", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "ClowkAudioInfo", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "ClowkAudioWave", { link = "NonText", default = true })
  vim.api.nvim_set_hl(0, "ClowkAudioPlayed", { link = "Special", default = true })
  vim.api.nvim_set_hl(0, "ClowkAudioStatus", { link = "Statement", default = true })
  vim.api.nvim_set_hl(0, "ClowkAudioKeys", { link = "Comment", default = true })

  local pattern = "*." .. table.concat(M.formats, ",*.")
  local group = vim.api.nvim_create_augroup("clowk_audio", { clear = true })

  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = pattern,
    callback = function(e)
      M.open(e.buf)
    end,
  })

  -- Without this, `:w` in the player would write the drawn text over the audio
  -- file. snacks.image guards its image buffers the same way.
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    pattern = pattern,
    callback = function(e)
      vim.bo[e.buf].modified = false
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      for _, p in pairs(players) do
        kill(p)
      end
    end,
  })
end

return M
