local t = ...
local host = require("lese.host")

t.describe("host.call", function()
  t.it("returns a Vim list as a plain Lua table", function()
    local result = host.call("split", "a b c")
    t.eq(type(result), "table")
    t.eq(result, { "a", "b", "c" })
  end)

  t.it("returns a Vim dict as a plain Lua table", function()
    local result = host.call("eval", "{'a': {'b': [1, 2]}}")
    t.eq(result, { a = { b = { 1, 2 } } })
  end)

  t.it("passes nested Lua tables to Vim", function()
    t.eq(host.call("len", { 1, 2, 3 }), 3)
    t.eq(host.call("get", { a = { b = 1 } }, "a"), { b = 1 })
  end)

  t.it("passes Lua booleans as Vim booleans", function()
    t.eq(host.call("type", true), host.call("type", host.call("eval", "v:true")))
  end)
end)

t.describe("host.cmd", function()
  t.it("runs an Ex command", function()
    host.cmd("let g:lese_host_test = 1")
    t.eq(host.call("eval", "g:lese_host_test"), 1)
  end)
end)
