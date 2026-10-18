local t = require("lese.testing")
local host = require("lese.host")

t.describe("host.call", function()
  t.it("returns a Vim list as a plain Lua table", function()
    t.eq(host.call("split", "a b c"), { "a", "b", "c" })
  end)

  t.it("returns a Vim dict as a plain Lua table", function()
    t.eq(host.call("eval", "{'a': {'b': [1, 2]}}"), { a = { b = { 1, 2 } } })
  end)

  t.it("passes nested Lua tables to Vim", function()
    t.eq(host.call("len", { 1, 2, 3 }), 3)
    t.eq(host.call("get", { a = { b = 1 } }, "a"), { b = 1 })
  end)

  t.it("passes Lua booleans as Vim booleans", function()
    t.eq(host.call("type", true), host.call("type", host.call("eval", "v:true")))
  end)

  t.it("passes an empty table as an empty list", function()
    t.eq(host.call("type", {}), host.call("type", host.call("eval", "[]")))
  end)
end)

t.describe("host.fn", function()
  t.it("calls the Vim function named by the field", function()
    t.eq(host.fn.toupper("abc"), "ABC")
  end)
end)

t.describe("host.cmd", function()
  t.it("runs an Ex command", function()
    host.cmd("let g:lese_host_test = 1")
    t.eq(host.eval("g:lese_host_test"), 1)
  end)
end)

t.describe("host.defer", function()
  t.it("calls back after the host processes its events", function()
    local called = false
    host.defer(1, function()
      called = true
    end)
    host.wait(1000, function()
      return called
    end)
    t.ok(called, "the timer did not fire")
  end)
end)

t.describe("host.spawn", function()
  local function run(cmd)
    local out, err, code = {}, {}, nil
    host.spawn(cmd, {
      on_stdout = function(line)
        out[#out + 1] = line
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function(c)
        code = c
      end,
    })
    host.wait(5000, function()
      return code ~= nil
    end)
    return out, err, code
  end

  t.it("delivers stdout line by line and the exit status after it", function()
    local out, _, code = run({ "sh", "-c", "printf 'a\\nb\\nc'" })
    t.eq(out, { "a", "b", "c" })
    t.eq(code, 0)
  end)

  t.it("strips the CR of CR LF line breaks", function()
    local out = run({ "sh", "-c", "printf 'a\\r\\nb\\r\\n'" })
    t.eq(out, { "a", "b" })
  end)

  t.it("delivers stderr apart from stdout", function()
    local out, err, code = run({ "sh", "-c", "echo out; echo err >&2; exit 3" })
    t.eq(out, { "out" })
    t.eq(err, { "err" })
    t.eq(code, 3)
  end)

  t.it("raises when the command cannot be started", function()
    t.raises(function()
      host.spawn({ "lese-no-such-command" }, {})
    end)
  end)
end)

t.describe("host.register", function()
  t.it("lets Vim script call a Lua function with arguments", function()
    local id = host.register(function(a, b)
      return a .. b
    end)
    t.eq(host.call("lese#internal#invoke", id, "x", "y"), "xy")
    host.unregister(id)
  end)
end)

t.describe("host.open_window", function()
  local dimension = { row = 2, col = 3, width = 20, height = 4 }

  t.it("opens a window holding the lines it is given", function()
    local win = host.open_window(dimension, { border = { "+", "-", "+", "|", "+", "-", "+", "|" } })
    win:set_lines({ "foo", "bar" })
    t.eq(host.fn.getbufline(win.bufnr, 1, "$"), { "foo", "bar" })
    win:close()
  end)

  t.it("decorates lines and clears the decorations", function()
    local win = host.open_window(dimension, {})
    win:set_lines({ "foobar" })
    win:decorate({ { line = 1, column = 4, length = 3, highlight = "Search" } })
    win:decorate({ { line = 1, column = 5, length = 100, highlight = "Search" } })
    win:undecorate()
    win:close()
  end)

  t.it("closes the window", function()
    local win = host.open_window(dimension, {})
    win:close()
    t.eq(host.fn.win_gettype(win.winid), "unknown")
  end)
end)
