-- The Vim (+lua) side of lese.host. Read lese/host/init.lua for the contract.
--# selene: allow(incorrect_standard_library_use)

local compat = require("lese.core.compat")

local M = {}

M.name = "vim"

-- Vim does not convert a plain Lua table passed to a Vim function, and returns
-- lists and dicts as userdata, so values are converted at the boundary.

local function to_vim(value)
  if type(value) ~= "table" then
    return value
  end
  -- An empty table becomes a list, as on Neovim.
  if next(value) == nil or value[1] ~= nil then
    local list = vim.list()
    for _, item in ipairs(value) do
      list:add(to_vim(item))
    end
    return list
  end
  local dict = vim.dict()
  for k, item in pairs(value) do
    dict[tostring(k)] = to_vim(item)
  end
  return dict
end

local function from_vim(value)
  local kind = vim.type(value)
  if kind == "list" then
    local result = {}
    for i = 1, #value do
      result[i] = from_vim(value[i])
    end
    return result
  elseif kind == "dict" then
    local result = {}
    for k, item in value() do
      result[k] = from_vim(item)
    end
    return result
  end
  return value
end

M.to_vim = to_vim
M.from_vim = from_vim

function M.call(name, ...)
  local n = select("#", ...)
  local args = { ... }
  for i = 1, n do
    args[i] = to_vim(args[i])
  end
  return from_vim(vim.call(name, compat.unpack(args, 1, n)))
end

function M.cmd(command)
  vim.command(command)
end

function M.now()
  return vim.fn.reltimefloat(vim.fn.reltime()) * 1000
end

-- `:sleep` handles timers and job callbacks while it waits.
function M.wait(ms, condition)
  local deadline = M.now() + ms
  while not (condition and condition()) and M.now() < deadline do
    vim.command("sleep 1m")
  end
end

function M.spawn(cmd, opts)
  local exited, closed, status = false, false, nil
  local pid
  local function finish()
    if exited and closed then
      vim.fn["lese#internal#job_forget"](pid)
      if opts.on_exit then
        opts.on_exit(status)
      end
    end
  end
  local function line_cb(on_line)
    return function(_, msg)
      if on_line then
        on_line((msg:gsub("\r$", "")))
      end
    end
  end
  local options = {
    in_io = "null",
    out_mode = "nl",
    err_mode = "nl",
    out_cb = line_cb(opts.on_stdout),
    err_cb = line_cb(opts.on_stderr),
    exit_cb = function(_, code)
      exited, status = true, code
      finish()
    end,
    close_cb = function()
      closed = true
      finish()
    end,
  }
  if opts.cwd then
    options.cwd = opts.cwd
  end
  if opts.env then
    options.env = opts.env
  end
  pid = vim.fn["lese#internal#job_start"](to_vim(cmd), to_vim(options))
  if pid == 0 then
    error(string.format("failed to start %s", tostring(cmd[1])), 0)
  end
  return {
    kill = function()
      vim.fn["lese#internal#job_stop"](pid)
    end,
  }
end

-- lese borders run clockwise from the top-left corner; Vim takes the sides
-- first and the corners after.
local function popup_border(border)
  if not border then
    return { border = { 0, 0, 0, 0 } }
  end
  local function width(c)
    return (c == nil or c == "") and 0 or 1
  end
  local function char(c)
    return (c == nil or c == "") and " " or c
  end
  return {
    border = { width(border[2]), width(border[4]), width(border[6]), width(border[8]) },
    borderchars = {
      char(border[2]),
      char(border[4]),
      char(border[6]),
      char(border[8]),
      char(border[1]),
      char(border[3]),
      char(border[5]),
      char(border[7]),
    },
  }
end

local function popup_options(dimension, opts)
  local options = {}
  if dimension then
    options.line = dimension.row
    options.col = dimension.col
    options.minwidth = math.max(1, dimension.width)
    options.maxwidth = math.max(1, dimension.width)
    options.minheight = math.max(1, dimension.height)
    options.maxheight = math.max(1, dimension.height)
  end
  if opts then
    if opts.border then
      local b = popup_border(opts.border)
      options.border = b.border
      options.borderchars = b.borderchars
    end
    if opts.zindex then
      options.zindex = opts.zindex
    end
    if opts.title and opts.title ~= "" then
      options.title = opts.title
    end
  end
  return options
end

function M.window_open(dimension, opts)
  local options = popup_options(dimension, opts)
  local b = popup_border(opts.border)
  options.border = b.border
  options.borderchars = b.borderchars
  options.pos = "topleft"
  options.fixed = 1
  options.wrap = 0
  options.scrollbar = 0
  options.mapping = 0
  options.highlight = (opts.highlight or {}).normal or "Normal"
  options.borderhighlight = { (opts.highlight or {}).border or "Normal" }
  local winid = vim.fn.popup_create("", to_vim(options))
  return winid, vim.fn.winbufnr(winid)
end

function M.window_config(winid, dimension, opts)
  local options = popup_options(dimension, opts)
  if dimension then
    vim.fn.popup_move(
      winid,
      to_vim({
        line = options.line,
        col = options.col,
        minwidth = options.minwidth,
        maxwidth = options.maxwidth,
        minheight = options.minheight,
        maxheight = options.maxheight,
      })
    )
  end
  options.line, options.col = nil, nil
  options.minwidth, options.maxwidth, options.minheight, options.maxheight = nil, nil, nil, nil
  if next(options) ~= nil then
    vim.fn.popup_setoptions(winid, to_vim(options))
  end
end

function M.window_close(winid)
  pcall(vim.fn.popup_close, winid)
end

-- Text property types are global; one is added per highlight group on demand.
local prop_types = {}

local function prop_type(highlight)
  local name = "lese:" .. highlight
  if not prop_types[name] then
    if vim.fn.empty(vim.fn.prop_type_get(name)) == 1 then
      vim.fn.prop_type_add(name, to_vim({ highlight = highlight, combine = 0, priority = 10 }))
    end
    prop_types[name] = true
  end
  return name
end

-- Line lengths are kept per buffer so decorations past the end are clipped;
-- prop_add() rejects a column beyond the line.
local line_lengths = {}

function M.set_lines(winid, bufnr, lines)
  if winid then
    vim.fn.popup_settext(winid, to_vim(lines))
  else
    vim.fn.setbufline(bufnr, 1, to_vim(lines))
    vim.fn.deletebufline(bufnr, #lines + 1, "$")
  end
  local lengths = {}
  for i, line in ipairs(lines) do
    lengths[i] = #line
  end
  line_lengths[bufnr] = lengths
end

function M.decorate(_, bufnr, decorations)
  local lengths = line_lengths[bufnr] or {}
  local groups = {}
  local order = {}
  for _, d in ipairs(decorations) do
    local len = lengths[d.line]
    if len and d.column <= len and d.length > 0 then
      local end_col = math.min(d.column + d.length, len + 1)
      local group = groups[d.highlight]
      if not group then
        group = {}
        groups[d.highlight] = group
        order[#order + 1] = d.highlight
      end
      group[#group + 1] = { d.line, d.column, d.line, end_col }
    end
  end
  for _, highlight in ipairs(order) do
    vim.fn.prop_add_list(
      to_vim({ type = prop_type(highlight), bufnr = bufnr }),
      to_vim(groups[highlight])
    )
  end
end

function M.undecorate(_, bufnr)
  local count = #(line_lengths[bufnr] or {})
  if count > 0 then
    pcall(vim.fn.prop_clear, 1, count, to_vim({ bufnr = bufnr }))
  end
end

-- Vim places signs in a popup only from a group whose name starts with PopUp.
M.sign_group = "PopUpLese"

return M
