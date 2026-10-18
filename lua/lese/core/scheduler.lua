-- Runs tasks as coroutines and gives control back to the editor whenever a
-- tick has used its time budget, so long work never freezes the editor. Read
-- docs/adr/20261018-run-modules-as-coroutines-under-a-time-sliced-scheduler.md.

local M = {}

---The error a cancelled task unwinds with. `tostring()` gives "cancelled".
M.CANCELLED = setmetatable({}, {
  __tostring = function()
    return "cancelled"
  end,
})

---@alias lese.TaskStatus "ready"|"running"|"waiting"|"done"|"failed"|"cancelled"

---@class lese.Task
---@field name string
---@field status lese.TaskStatus
---@field error? any       -- the value the task raised, when it failed
---@field traceback? string
---@field package co thread
---@field cancelled boolean   -- set by cancel(); the task unwinds at its next checkpoint
---@field package woken boolean
---@field package started? boolean
---@field package starved? boolean
---@field package mark number
---@field package hooks (fun())[]
---@field package scheduler lese.Scheduler
---@field package opts lese.TaskOptions
local Task = {}
Task.__index = Task

---@class lese.TaskOptions
---@field name? string
---@field on_done? fun(task: lese.Task)    -- after the function returned
---@field on_error? fun(task: lese.Task)   -- after the function raised
---@field on_cancel? fun(task: lese.Task)  -- after the task unwound from a cancel

---@class lese.SchedulerOptions
---@field budget? number          -- milliseconds a tick may run, default 8
---@field starve_ms? number       -- report a task that runs this long between checkpoints
---@field on_starve? fun(task: lese.Task, elapsed: number)
---@field clock? fun(): number    -- milliseconds; default os.clock()
---@field defer? fun(ms: integer, callback: fun()) -- run ticks on its own when given

---@class lese.Scheduler
---@field budget number
---@field current? lese.Task
---@field starve_ms number
---@field on_starve? fun(task: lese.Task, elapsed: number)
---@field package clock fun(): number
---@field package defer? fun(ms: integer, callback: fun())
---@field package queue lese.Task[]
---@field package waiting table<lese.Task, true>
---@field package deadline number
---@field package scheduled boolean
local Scheduler = {}
Scheduler.__index = Scheduler

local function default_clock()
  return os.clock() * 1000
end

---@param opts? lese.SchedulerOptions
---@return lese.Scheduler
function M.new(opts)
  opts = opts or {}
  return setmetatable({
    budget = opts.budget or 8,
    starve_ms = opts.starve_ms or 50,
    on_starve = opts.on_starve,
    clock = opts.clock or default_clock,
    defer = opts.defer,
    queue = {},
    waiting = {},
    deadline = math.huge,
    scheduled = false,
  }, Scheduler)
end

function Scheduler:schedule()
  if self.defer and not self.scheduled and #self.queue > 0 then
    self.scheduled = true
    self.defer(1, function()
      self.scheduled = false
      self:tick()
      self:schedule()
    end)
  end
end

---Start `fn` as a task. It runs on the next tick.
---@param fn fun()
---@param opts? lese.TaskOptions
---@return lese.Task
function Scheduler:spawn(fn, opts)
  opts = opts or {}
  local task = setmetatable({
    name = opts.name or "task",
    status = "ready",
    co = coroutine.create(fn),
    cancelled = false,
    woken = false,
    hooks = {},
    scheduler = self,
    opts = opts,
  }, Task)
  self.queue[#self.queue + 1] = task
  self:schedule()
  return task
end

local function finish(task, status)
  task.status = status
  task.scheduler.waiting[task] = nil
  local hooks = task.hooks
  task.hooks = {}
  -- A failed task leaves what it started (a command) behind unless its hooks
  -- release it, as a cancel would.
  if status == "failed" then
    for _, hook in ipairs(hooks) do
      pcall(hook)
    end
  end
  local callback
  if status == "done" then
    callback = task.opts.on_done
  elseif status == "failed" then
    callback = task.opts.on_error
  else
    callback = task.opts.on_cancel
  end
  if callback then
    callback(task)
  end
end

---@param task lese.Task
function Scheduler:resume(task)
  local previous = self.current
  self.current = task
  task.status = "running"
  task.started = true
  task.mark = self.clock()
  local ok, err = coroutine.resume(task.co)
  self.current = previous
  self:measure(task, self.clock())
  if not ok then
    if err == M.CANCELLED then
      finish(task, "cancelled")
    else
      task.error = err
      local message = type(err) == "table" and (err.message or tostring(err)) or tostring(err)
      task.traceback = debug.traceback(task.co, message)
      finish(task, "failed")
    end
  elseif coroutine.status(task.co) == "dead" then
    finish(task, task.cancelled and "cancelled" or "done")
  elseif task.status == "running" then
    task.status = "ready"
    self.queue[#self.queue + 1] = task
  end
end

---Run ready tasks, in turn, until none is ready or the budget is used.
---@return boolean more true when a task is still ready to run
function Scheduler:tick()
  self.deadline = self.clock() + self.budget
  while #self.queue > 0 do
    local task = table.remove(self.queue, 1)
    if task.status == "ready" then
      self:resume(task)
    end
    if self.clock() >= self.deadline then
      break
    end
  end
  self.deadline = math.huge
  return #self.queue > 0
end

---Run ticks until no task is ready. Tasks waiting on something outside the
---scheduler stay waiting.
---@param max_ticks? integer
function Scheduler:drain(max_ticks)
  local ticks = 0
  while self:tick() do
    ticks = ticks + 1
    if max_ticks and ticks >= max_ticks then
      return
    end
  end
end

---@class lese.RunUntilOptions
---@field now fun(): number                 -- milliseconds
---@field wait? fun(ms: number, condition?: fun(): boolean) -- process the editor's events
---@field timeout? number                   -- milliseconds

---Run ticks until `done()` holds, giving the editor (through `wait`) a turn
---between ticks, so a long task neither freezes the editor nor outlives
---`timeout`. Returns false on timeout. Without `wait`, a task that waits on
---something outside the scheduler raises.
---@param done fun(): boolean
---@param opts lese.RunUntilOptions
---@return boolean
function Scheduler:run_until(done, opts)
  local deadline = opts.now() + (opts.timeout or math.huge)
  while not done() do
    if opts.now() >= deadline then
      return false
    end
    self:tick()
    if not done() then
      if opts.wait then
        if self:ready() then
          -- A ready task must not keep the editor from its timers and jobs.
          opts.wait(1, nil)
        else
          opts.wait(10, function()
            return self:ready()
          end)
        end
      elseif not self:ready() then
        error("a task waits on the editor, which a bare Lua does not have", 2)
      end
    end
  end
  return true
end

---The scheduler's clock, in milliseconds.
---@return number
function Scheduler:now()
  return self.clock()
end

---True while a task is ready to run.
---@return boolean
function Scheduler:ready()
  return #self.queue > 0
end

---True while a task is ready or waiting.
---@return boolean
function Scheduler:busy()
  return #self.queue > 0 or next(self.waiting) ~= nil
end

---@param task lese.Task
---@param now number
function Scheduler:measure(task, now)
  if self.on_starve and not task.starved and now - task.mark > self.starve_ms then
    task.starved = true
    self.on_starve(task, now - task.mark)
  end
  task.mark = now
end

---Inside a task: raise if the task was cancelled, and yield when the tick's
---budget is used. Outside a task it does nothing.
function Scheduler:checkpoint()
  local task = self.current
  if not task then
    return
  end
  if task.cancelled then
    error(M.CANCELLED, 0)
  end
  local now = self.clock()
  self:measure(task, now)
  if now >= self.deadline then
    coroutine.yield()
    if task.cancelled then
      error(M.CANCELLED, 0)
    end
  end
end

---Inside a task: wait until `wake` is called for it, then raise if the task was
---cancelled meanwhile.
function Scheduler:suspend()
  local task = self.current
  if not task then
    error("suspend() is called outside a task", 2)
  end
  if task.cancelled then
    error(M.CANCELLED, 0)
  end
  if task.woken then
    task.woken = false
    return
  end
  task.status = "waiting"
  self.waiting[task] = true
  coroutine.yield()
  task.woken = false
  if task.cancelled then
    error(M.CANCELLED, 0)
  end
end

---Make a waiting task ready. Waking a task that is not waiting makes its next
---`suspend` return at once.
---@param task lese.Task
function Scheduler:wake(task)
  if task.status == "waiting" then
    task.status = "ready"
    self.waiting[task] = nil
    self.queue[#self.queue + 1] = task
    self:schedule()
  elseif task.status == "ready" or task.status == "running" then
    task.woken = true
  end
end

---Cancel the task. It unwinds from its next checkpoint; a waiting task is
---woken to do so. Hooks added with `on_cancel` run at once.
function Task:cancel()
  if self.cancelled or self.status == "done" or self.status == "failed" then
    return
  end
  self.cancelled = true
  local hooks = self.hooks
  self.hooks = {}
  for _, hook in ipairs(hooks) do
    hook()
  end
  if self.status == "waiting" then
    self.scheduler:wake(self)
  elseif self.status == "ready" and not self.started then
    -- A task that never started has nothing to unwind.
    for i, task in ipairs(self.scheduler.queue) do
      if task == self then
        table.remove(self.scheduler.queue, i)
        break
      end
    end
    finish(self, "cancelled")
  end
end

---Run `hook` if the task is cancelled before it finishes.
---@param hook fun()
---@return fun() remove
function Task:on_cancel(hook)
  local hooks = self.hooks
  hooks[#hooks + 1] = hook
  return function()
    for i, h in ipairs(self.hooks) do
      if h == hook then
        table.remove(self.hooks, i)
        return
      end
    end
  end
end

---True once the task stopped, whatever the reason.
---@return boolean
function Task:finished()
  return self.status == "done" or self.status == "failed" or self.status == "cancelled"
end

return M
