-- The Neovim side of lese.host. Read lese/host/init.lua for the contract.
--# selene: allow(incorrect_standard_library_use)

local M = {}

M.name = "nvim"

local uv = vim.uv or vim.loop
local ns = vim.api.nvim_create_namespace("lese")

function M.call(name, ...)
  return vim.call(name, ...)
end

function M.cmd(command)
  vim.cmd(command)
end

function M.now()
  return uv.hrtime() / 1e6
end

function M.wait(ms, condition)
  vim.wait(ms, condition or function()
    return false
  end, 1)
end

---Split chunks from jobstart() into lines. The first element continues the
---previous chunk's last line; the last one is incomplete until the next chunk.
local function line_splitter(on_line)
  local pending = ""
  local function feed(data)
    if not on_line then
      return
    end
    for i, part in ipairs(data) do
      if i == 1 then
        pending = pending .. part
      else
        local line = pending:gsub("\r$", "")
        on_line(line)
        pending = part
      end
    end
  end
  local function flush()
    if on_line and pending ~= "" then
      local line = pending:gsub("\r$", "")
      on_line(line)
    end
    pending = ""
  end
  return feed, flush
end

function M.spawn(cmd, opts)
  local feed_out, flush_out = line_splitter(opts.on_stdout)
  local feed_err, flush_err = line_splitter(opts.on_stderr)
  local ok, job = pcall(vim.fn.jobstart, cmd, {
    cwd = opts.cwd,
    env = opts.env,
    stdin = "null",
    on_stdout = function(_, data)
      feed_out(data)
    end,
    on_stderr = function(_, data)
      feed_err(data)
    end,
    on_exit = function(_, code)
      flush_out()
      flush_err()
      if opts.on_exit then
        opts.on_exit(code)
      end
    end,
  })
  if not ok or job <= 0 then
    error(string.format("failed to start %s: %s", tostring(cmd[1]), ok and job or tostring(job)), 0)
  end
  return {
    kill = function()
      pcall(vim.fn.jobstop, job)
    end,
  }
end

local function float_config(dimension, opts)
  local config = {
    relative = "editor",
    row = dimension.row - 1,
    col = dimension.col - 1,
    width = math.max(1, dimension.width),
    height = math.max(1, dimension.height),
  }
  if opts then
    if opts.border then
      config.border = opts.border
    end
    if opts.zindex then
      config.zindex = opts.zindex
    end
    if opts.title and opts.title ~= "" then
      config.title = opts.title
      config.title_pos = "left"
    end
  end
  return config
end

function M.window_open(dimension, opts)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  local config = float_config(dimension, opts)
  config.style = "minimal"
  config.focusable = false
  config.noautocmd = true
  if not config.border then
    config.border = "none"
    config.title = nil
  end
  local winid = vim.api.nvim_open_win(bufnr, false, config)
  local highlight = opts.highlight or {}
  vim.wo[winid].winhighlight = string.format(
    "Normal:%s,FloatBorder:%s,FloatTitle:%s",
    highlight.normal or "NormalFloat",
    highlight.border or "FloatBorder",
    highlight.border or "FloatTitle"
  )
  return winid, bufnr
end

function M.window_config(winid, dimension, opts)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  local current = vim.api.nvim_win_get_config(winid)
  local config = float_config(dimension or {
    row = current.row + 1,
    col = current.col + 1,
    width = current.width,
    height = current.height,
  }, opts)
  pcall(vim.api.nvim_win_set_config, winid, config)
end

function M.window_close(winid)
  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
end

function M.set_lines(_, bufnr, lines)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local modifiable = vim.bo[bufnr].modifiable
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = modifiable
end

function M.decorate(_, bufnr, decorations)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  for _, d in ipairs(decorations) do
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, d.line - 1, d.column - 1, {
      end_col = d.column - 1 + d.length,
      hl_group = d.highlight,
      strict = false,
    })
  end
end

function M.undecorate(_, bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

M.sign_group = "lese"

return M
