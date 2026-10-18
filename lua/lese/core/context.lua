-- The `ctx` every module function receives as its first argument.

local scheduler_mod = require("lese.core.scheduler")

local M = {}

---@class lese.Context
---@field host lese.Host     -- the editor; the only way a module reaches it
---@field name string        -- the name of the module being run
---@field package scheduler lese.Scheduler
---@field package sink? fun(items: lese.Item[])
local Context = {}
Context.__index = Context

---@class lese.ContextOptions
---@field scheduler lese.Scheduler
---@field host? lese.Host
---@field name? string
---@field sink? fun(items: lese.Item[])

---@param opts lese.ContextOptions
---@return lese.Context
function M.new(opts)
  return setmetatable({
    scheduler = opts.scheduler,
    host = opts.host,
    name = opts.name or "module",
    sink = opts.sink,
  }, Context)
end

---A copy that reports results to another sink under another name.
---@param overrides { name?: string, sink?: fun(items: lese.Item[]) }
---@return lese.Context
function Context:derive(overrides)
  return setmetatable({
    scheduler = self.scheduler,
    host = self.host,
    name = overrides.name or self.name,
    sink = overrides.sink or self.sink,
  }, Context)
end

local function is_item(value)
  return type(value) == "table" and (value.value ~= nil or value.id ~= nil or value.detail ~= nil)
end

---Hand an item, or a list of items, over to whoever runs the module.
---@param item_or_items lese.Item|lese.Item[]
function Context:emit(item_or_items)
  if not self.sink then
    error(self.name .. ": emit() is not available in this module", 2)
  end
  if is_item(item_or_items) then
    self.sink({ item_or_items })
  elseif type(item_or_items) == "table" then
    if #item_or_items > 0 then
      self.sink(item_or_items)
    end
  else
    error(
      string.format(
        "%s: emit() takes an item or a list of items, got %s",
        self.name,
        type(item_or_items)
      ),
      2
    )
  end
end

---Give the scheduler a chance to pause or cancel the module. Call it in every
---loop that may run long.
function Context:checkpoint()
  self.scheduler:checkpoint()
end

---True once the run was cancelled. The next `checkpoint()` raises.
---@return boolean
function Context:cancelled()
  local task = self.scheduler.current
  return task ~= nil and task.cancelled == true
end

---Wait until `start` calls the function it receives, and return what was
---passed to it. A cancel unwinds the wait.
---@param start fun(resolve: fun(value?: any)): (fun()|nil) -- may return a function that undoes `start` on cancel
---@return any
function Context:await(start)
  local scheduler = self.scheduler
  local task = scheduler.current
  if not task then
    error(self.name .. ": await() is called outside a module run", 2)
  end
  local resolved, result = false, nil
  local undo = start(function(value)
    if not resolved then
      resolved, result = true, value
      scheduler:wake(task)
    end
  end)
  local remove = undo and task:on_cancel(undo)
  while not resolved do
    scheduler:suspend()
  end
  if remove then
    remove()
  end
  return result
end

---Wait `ms` milliseconds without blocking the editor.
---@param ms integer
function Context:sleep(ms)
  local host = self.host
  self:await(function(resolve)
    local timer = host.defer(ms, resolve)
    return function()
      host.stop_timer(timer)
    end
  end)
end

---@class lese.ContextSpawnOptions
---@field cwd? string
---@field env? table<string, string>
---@field on_stdout? fun(line: string) -- runs in the module; may emit and checkpoint
---@field on_stderr? fun(line: string)

---Run an external command and wait for it to exit. Output lines reach the
---handlers inside the module, so they may `emit`. A cancel kills the command.
---@param cmd string[]
---@param opts? lese.ContextSpawnOptions
---@return integer code the exit status
function Context:spawn(cmd, opts)
  opts = opts or {}
  local scheduler = self.scheduler
  local task = scheduler.current
  if not task then
    error(self.name .. ": spawn() is called outside a module run", 2)
  end
  local queue, head = {}, 1
  local code
  local job = self.host.spawn(cmd, {
    cwd = opts.cwd,
    env = opts.env,
    on_stdout = function(line)
      queue[#queue + 1] = { opts.on_stdout, line }
      scheduler:wake(task)
    end,
    on_stderr = function(line)
      queue[#queue + 1] = { opts.on_stderr, line }
      scheduler:wake(task)
    end,
    on_exit = function(c)
      code = c
      scheduler:wake(task)
    end,
  })
  local remove = task:on_cancel(job.kill)
  while true do
    while head <= #queue do
      local entry = queue[head]
      queue[head] = nil
      head = head + 1
      if entry[1] then
        entry[1](entry[2])
      end
      scheduler:checkpoint()
    end
    if code ~= nil then
      break
    end
    scheduler:suspend()
  end
  remove()
  return code --[[@as integer]]
end

M.CANCELLED = scheduler_mod.CANCELLED

return M
