local t = require("lese.testing")
local scheduler_mod = require("lese.core.scheduler")
local context = require("lese.core.context")

local function run(fn, host)
  local s = scheduler_mod.new()
  local emitted = {}
  local ctx = context.new({
    scheduler = s,
    host = host,
    name = "test.module",
    sink = function(items)
      for _, item in ipairs(items) do
        emitted[#emitted + 1] = item
      end
    end,
  })
  local task = s:spawn(function()
    fn(ctx)
  end)
  return s, task, emitted
end

t.describe("ctx:emit", function()
  t.it("takes a single item", function()
    local s, _, emitted = run(function(ctx)
      ctx:emit({ id = 1, value = "a", detail = {} })
    end)
    s:drain()
    t.eq(emitted, { { id = 1, value = "a", detail = {} } })
  end)

  t.it("takes a list of items", function()
    local s, _, emitted = run(function(ctx)
      ctx:emit({ { id = 1, value = "a", detail = {} }, { id = 2, value = "b", detail = {} } })
    end)
    s:drain()
    t.eq(#emitted, 2)
  end)

  t.it("names the module when given something else", function()
    local s, task = run(function(ctx)
      ctx:emit("a")
    end)
    s:drain()
    t.eq(task.status, "failed")
    t.ok(string.find(tostring(task.error), "test.module: emit() takes an item", 1, true))
  end)
end)

t.describe("ctx:await", function()
  t.it("returns what the starter resolves with", function()
    local resolve
    local result
    local s = run(function(ctx)
      result = ctx:await(function(r)
        resolve = r
      end)
    end)
    s:drain()
    t.eq(result, nil)
    resolve(42)
    s:drain()
    t.eq(result, 42)
  end)

  t.it("undoes the starter when cancelled", function()
    local undone = false
    local s, task = run(function(ctx)
      ctx:await(function()
        return function()
          undone = true
        end
      end)
    end)
    s:drain()
    task:cancel()
    s:drain()
    t.eq(undone, true)
    t.eq(task.status, "cancelled")
  end)
end)

t.describe("ctx:spawn", function()
  -- A host whose jobs the test drives by hand.
  local function fake_host()
    local job = { killed = false }
    local host = {
      spawn = function(_, opts)
        job.opts = opts
        return {
          kill = function()
            job.killed = true
          end,
        }
      end,
    }
    return host, job
  end

  t.it("hands output lines to the handlers inside the module and returns the status", function()
    local host, job = fake_host()
    local code
    local s, _, emitted = run(function(ctx)
      code = ctx:spawn({ "cmd" }, {
        on_stdout = function(line)
          ctx:emit({ id = line, value = line, detail = {} })
        end,
      })
    end, host)
    s:drain()
    job.opts.on_stdout("a")
    job.opts.on_stdout("b")
    s:drain()
    t.eq(#emitted, 2)
    job.opts.on_exit(0)
    s:drain()
    t.eq(code, 0)
  end)

  t.it("keeps lines that arrive after the earlier ones were handled", function()
    local host, job = fake_host()
    local s, _, emitted = run(function(ctx)
      ctx:spawn({ "cmd" }, {
        on_stdout = function(line)
          ctx:emit({ id = line, value = line, detail = {} })
        end,
      })
    end, host)
    s:drain()
    job.opts.on_stdout("a")
    s:drain()
    job.opts.on_stdout("b")
    s:drain()
    job.opts.on_exit(0)
    s:drain()
    t.eq(t.values(emitted), { "a", "b" })
  end)

  t.it("kills the command when an output handler fails", function()
    local host, job = fake_host()
    local s, task = run(function(ctx)
      ctx:spawn({ "cmd" }, {
        on_stdout = function()
          error("parse error")
        end,
      })
    end, host)
    s:drain()
    job.opts.on_stdout("a")
    s:drain()
    t.eq(task.status, "failed")
    t.eq(job.killed, true)
  end)

  t.it("kills the command when cancelled", function()
    local host, job = fake_host()
    local s, task = run(function(ctx)
      ctx:spawn({ "cmd" })
    end, host)
    s:drain()
    task:cancel()
    s:drain()
    t.eq(job.killed, true)
    t.eq(task.status, "cancelled")
  end)
end)
