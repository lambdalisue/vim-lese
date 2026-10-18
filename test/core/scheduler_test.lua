local t = require("lese.testing")
local scheduler_mod = require("lese.core.scheduler")

-- A clock the test moves by hand, so time slicing is deterministic.
local function manual_clock()
  local now = 0
  return function()
    return now
  end, function(ms)
    now = now + ms
  end
end

t.describe("scheduler", function()
  t.it("runs a spawned task on the next tick, not before", function()
    local s = scheduler_mod.new()
    local ran = false
    local task = s:spawn(function()
      ran = true
    end)
    t.eq(ran, false)
    s:tick()
    t.eq(ran, true)
    t.eq(task.status, "done")
  end)

  t.it("yields at a checkpoint once the tick has used its budget", function()
    local clock, advance = manual_clock()
    local s = scheduler_mod.new({ budget = 8, clock = clock })
    local steps = 0
    s:spawn(function()
      for _ = 1, 3 do
        steps = steps + 1
        advance(5)
        s:checkpoint()
      end
    end)
    t.eq(s:tick(), true)
    t.eq(steps, 2)
    t.eq(s:tick(), false)
    t.eq(steps, 3)
  end)

  t.it("does not yield at a checkpoint within the budget", function()
    local clock = manual_clock()
    local s = scheduler_mod.new({ budget = 8, clock = clock })
    local steps = 0
    s:spawn(function()
      for _ = 1, 100 do
        steps = steps + 1
        s:checkpoint()
      end
    end)
    t.eq(s:tick(), false)
    t.eq(steps, 100)
  end)

  t.it("takes turns between ready tasks across ticks", function()
    local clock, advance = manual_clock()
    local s = scheduler_mod.new({ budget = 1, clock = clock })
    local log = {}
    for _, name in ipairs({ "a", "b" }) do
      s:spawn(function()
        for i = 1, 2 do
          log[#log + 1] = name .. i
          advance(1)
          s:checkpoint()
        end
      end)
    end
    s:drain()
    t.eq(log, { "a1", "b1", "a2", "b2" })
  end)

  t.it("unwinds a cancelled task at its next checkpoint", function()
    local clock, advance = manual_clock()
    local s = scheduler_mod.new({ budget = 1, clock = clock })
    local reached = false
    local cancelled_with
    local task = s:spawn(function()
      advance(1)
      s:checkpoint()
      reached = true
    end, {
      on_cancel = function(cancelled)
        cancelled_with = cancelled.status
      end,
    })
    s:tick()
    task:cancel()
    s:drain()
    t.eq(reached, false)
    t.eq(task.status, "cancelled")
    t.eq(cancelled_with, "cancelled")
  end)

  t.it("drops a task cancelled before it started", function()
    local s = scheduler_mod.new()
    local ran = false
    local task = s:spawn(function()
      ran = true
    end)
    task:cancel()
    s:drain()
    t.eq(ran, false)
    t.eq(task.status, "cancelled")
    t.eq(s:busy(), false)
  end)

  t.it("reports a failed task with its error and a traceback", function()
    local s = scheduler_mod.new()
    local failed
    local task = s:spawn(function()
      error("boom")
    end, {
      on_error = function(errored)
        failed = errored
      end,
    })
    s:drain()
    t.eq(task.status, "failed")
    t.eq(failed, task)
    t.ok(string.find(tostring(task.error), "boom", 1, true))
    t.ok(string.find(task.traceback, "stack traceback", 1, true))
  end)

  t.it("keeps a suspended task waiting until it is woken", function()
    local s = scheduler_mod.new()
    local task
    local resumed = false
    task = s:spawn(function()
      s:suspend()
      resumed = true
    end)
    s:drain()
    t.eq(task.status, "waiting")
    t.eq(s:busy(), true)
    s:wake(task)
    s:drain()
    t.eq(resumed, true)
    t.eq(s:busy(), false)
  end)

  t.it("returns from suspend at once when woken beforehand", function()
    local s = scheduler_mod.new()
    local task
    task = s:spawn(function()
      s:wake(task)
      s:suspend()
    end)
    s:drain()
    t.eq(task.status, "done")
  end)

  t.it("unwinds a waiting task when it is cancelled and runs its hooks", function()
    local s = scheduler_mod.new()
    local hooked = false
    local task
    task = s:spawn(function()
      task:on_cancel(function()
        hooked = true
      end)
      s:suspend()
    end)
    s:drain()
    task:cancel()
    t.eq(hooked, true)
    s:drain()
    t.eq(task.status, "cancelled")
  end)

  t.it("reports a task that runs too long between checkpoints, once", function()
    local clock, advance = manual_clock()
    local reports = {}
    local s = scheduler_mod.new({
      clock = clock,
      budget = 1000,
      starve_ms = 50,
      on_starve = function(task, elapsed)
        reports[#reports + 1] = { task.name, elapsed }
      end,
    })
    s:spawn(function()
      advance(10)
      s:checkpoint()
      advance(60)
      s:checkpoint()
      advance(60)
    end, { name = "slow" })
    s:drain()
    t.eq(reports, { { "slow", 60 } })
  end)

  t.it("runs ticks until done, handing the editor a turn between them", function()
    local clock, advance = manual_clock()
    local s = scheduler_mod.new({ budget = 1, clock = clock })
    local steps, turns = 0, 0
    local task = s:spawn(function()
      for _ = 1, 3 do
        steps = steps + 1
        advance(1)
        s:checkpoint()
      end
    end)
    local done = s:run_until(function()
      return task:finished()
    end, {
      now = clock,
      wait = function()
        turns = turns + 1
      end,
    })
    t.eq(done, true)
    t.eq(steps, 3)
    t.ok(turns >= 2, "the editor got " .. turns .. " turns")
  end)

  t.it("gives up on run_until after the timeout even while the task checkpoints", function()
    local clock, advance = manual_clock()
    local s = scheduler_mod.new({ budget = 1, clock = clock })
    s:spawn(function()
      while true do
        advance(1)
        s:checkpoint()
      end
    end)
    local done = s:run_until(function()
      return false
    end, { now = clock, wait = function() end, timeout = 50 })
    t.eq(done, false)
  end)

  t.it("ticks on its own through defer when given one", function()
    local deferred = {}
    local s = scheduler_mod.new({
      defer = function(_, callback)
        deferred[#deferred + 1] = callback
      end,
    })
    local ran = false
    s:spawn(function()
      ran = true
    end)
    t.eq(#deferred, 1)
    s:spawn(function() end)
    t.eq(#deferred, 1)
    table.remove(deferred, 1)()
    t.eq(ran, true)
    t.eq(#deferred, 0)
  end)
end)
