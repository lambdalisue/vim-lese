-- lese.host is the one place that knows whether lese runs on Neovim or Vim.
-- Every function takes and returns plain Lua values on both hosts, so code
-- outside lua/lese/host/ never branches on the host.
--# selene: allow(incorrect_standard_library_use)

---@class lese.Dimension
---@field row integer    -- 1-based screen row of the window's top-left corner, border included
---@field col integer    -- 1-based screen column of the same corner
---@field width integer  -- inner width, border excluded
---@field height integer -- inner height, border excluded

---@alias lese.Border string[] -- topleft, top, topright, right, botright, bottom, botleft, left; "" omits that part

---@class lese.WindowOptions
---@field border? lese.Border -- nil draws no border
---@field title? string -- shown on the top border
---@field zindex? integer -- stacking order; higher is on top
---@field highlight? { normal?: string, border?: string } -- highlight groups for the text and the border

---@class lese.HostDecoration
---@field line integer     -- 1-based line
---@field column integer   -- 1-based byte column
---@field length integer   -- in bytes
---@field highlight string -- the highlight group

---@class lese.SpawnOptions
---@field cwd? string                  -- the directory to run in, default: the current one
---@field env? table<string, string>   -- variables added to the environment
---@field on_stdout? fun(line: string) -- called with each line on stdout
---@field on_stderr? fun(line: string) -- called with each line on stderr
---@field on_exit? fun(code: integer)  -- called with the exit status once the command exits

---@class lese.Job
---@field kill fun() -- stops the command

local impl
if vim.api ~= nil then
  impl = require("lese.host.nvim")
else
  impl = require("lese.host.vim")
end

---@class lese.Host
local M = {}

---"nvim" or "vim".
---@type "nvim"|"vim"
M.name = impl.name

---True on Neovim, false on Vim (+lua).
M.is_nvim = impl.name == "nvim"

---Call a Vim function.
---@param name string
---@return any
function M.call(name, ...)
  return impl.call(name, ...)
end

---Vim functions as fields: `host.fn.getcwd()`.
---@type table<string, fun(...): any>
M.fn = setmetatable({}, {
  __index = function(t, name)
    local f = function(...)
      return impl.call(name, ...)
    end
    rawset(t, name, f)
    return f
  end,
})

---Run an Ex command.
---@param command string
function M.cmd(command)
  impl.cmd(command)
end

---Evaluate a Vim expression.
---@param expr string
---@return any
function M.eval(expr)
  return impl.call("eval", expr)
end

---Milliseconds on a monotonic clock.
---@return number
function M.now()
  return impl.now()
end

---Process the host's events (timers, jobs) for up to `ms` milliseconds, or
---until `condition` returns true.
---@param ms number
---@param condition? fun(): boolean
function M.wait(ms, condition)
  impl.wait(ms, condition)
end

---Call `callback` after `ms` milliseconds.
---@param ms integer
---@param callback fun()
---@return integer timer
function M.defer(ms, callback)
  return impl.defer(ms, callback)
end

---Stop a timer started by `defer`.
---@param timer integer
function M.stop_timer(timer)
  pcall(impl.call, "timer_stop", timer)
end

---@class lese.DirEntry
---@field name string
---@field kind "file"|"dir"|"link" -- "link" is a symbolic link to a directory; one to a file is "file"

---The entries of directory `dir`, with their kinds, in one call; nil when it
---cannot be read. Entries that are neither files nor directories are left out.
---@param dir string
---@return lese.DirEntry[]?
function M.readdir(dir)
  return impl.readdir(dir)
end

---Run an external command. Output arrives line by line, without the line
---break (CR LF included).
---@param cmd string[]
---@param opts? lese.SpawnOptions
---@return lese.Job
function M.spawn(cmd, opts)
  -- Vim forks before it fails to exec, so a missing command would only show
  -- up as exit status 127; check up front so both hosts raise.
  if impl.call("executable", cmd[1]) ~= 1 then
    error(string.format("%s is not executable", tostring(cmd[1])), 2)
  end
  return impl.spawn(cmd, opts or {})
end

---The size of the editor screen.
---@return { width: integer, height: integer }
function M.screen()
  return { width = impl.call("eval", "&columns"), height = impl.call("eval", "&lines") }
end

---Show a message in the message history, with an optional highlight group.
---@param message string
---@param highlight? string
function M.echo(message, highlight)
  impl.call("lese#internal#echomsg", message, highlight or "None")
end

---Fire a `User` autocmd.
---@param pattern string
function M.emit(pattern)
  impl.call("lese#internal#emit", pattern)
end

---Turn a value Vim script handed to Lua (`_A` of luaeval()) into plain Lua.
---@param value any
---@return any
function M.import(value)
  if impl.from_vim then
    return impl.from_vim(value)
  end
  return value
end

---Turn a Lua value into one Vim script receives as a List or Dict when it is
---returned from luaeval().
---@param value any
---@return any
function M.export(value)
  if impl.to_vim then
    return impl.to_vim(value)
  end
  return value
end

-- Lua functions Vim script calls back through lese#internal#invoke().
local callbacks = {}
local next_callback = 0

---Register a function Vim script can call with `lese#internal#invoke(id, ...)`.
---@param callback fun(...): any
---@return integer id
function M.register(callback)
  next_callback = next_callback + 1
  callbacks[next_callback] = callback
  return next_callback
end

---Forget a function registered with `register`.
---@param id integer
function M.unregister(id)
  callbacks[id] = nil
end

---Called by lese#internal#invoke().
---@param id integer
---@param args any[]
---@return any
function M.invoke(id, args)
  local key, values = M.import(id), M.import(args)
  local callback = callbacks[key]
  if not callback then
    return nil
  end
  return M.export(callback(require("lese.core.compat").unpack(values or {})))
end

---A floating window (Neovim) or a popup (Vim) that never takes focus.
---@class lese.Window
---@field winid integer -- the window ID
---@field bufnr integer -- the buffer shown in it
local Window = {}
Window.__index = Window

---Open a window that never takes focus at `dimension`.
---@param dimension lese.Dimension
---@param opts? lese.WindowOptions
---@return lese.Window
function M.open_window(dimension, opts)
  local winid, bufnr = impl.window_open(dimension, opts or {})
  return setmetatable({ winid = winid, bufnr = bufnr }, Window)
end

---Move or resize the window, or change its options; nil leaves that part as it is.
---@param dimension? lese.Dimension
---@param opts? lese.WindowOptions
function Window:config(dimension, opts)
  impl.window_config(self.winid, dimension, opts)
end

---Replace every line.
---@param lines string[]
function Window:set_lines(lines)
  impl.set_lines(self.winid, self.bufnr, lines)
end

---Add highlights to the window's buffer.
---@param decorations lese.HostDecoration[]
function Window:decorate(decorations)
  impl.decorate(self.winid, self.bufnr, decorations)
end

---Remove every highlight `decorate` added.
function Window:undecorate()
  impl.undecorate(self.winid, self.bufnr)
end

---Run an Ex command in the window's context.
---@param command string
function Window:execute(command)
  impl.call("win_execute", self.winid, command)
end

---Place `sign` on each line in `lines`, replacing what was placed before.
---@param sign string
---@param lines integer[]
function Window:place_signs(sign, lines)
  impl.call("sign_unplace", impl.sign_group, { buffer = self.bufnr })
  local list = {}
  for i, lnum in ipairs(lines) do
    list[i] = { buffer = self.bufnr, group = impl.sign_group, name = sign, lnum = lnum }
  end
  if #list > 0 then
    impl.call("sign_placelist", list)
  end
end

---The value of a window-local option.
---@param name string
---@return any
function Window:option(name)
  return impl.call("getwinvar", self.winid, "&" .. name)
end

---Close the window.
function Window:close()
  impl.window_close(self.winid)
end

return M
