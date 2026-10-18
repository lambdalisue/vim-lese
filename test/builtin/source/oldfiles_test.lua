local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

t.describe("builtin.source.oldfiles", function()
  t.it("emits v:oldfiles in order with the path in detail", function()
    host.cmd("let v:oldfiles = ['/a/one', '/b/two']")
    local items = t.collect(builtin.source.oldfiles())
    t.eq(items, {
      { id = 1, value = "/a/one", detail = { path = "/a/one" } },
      { id = 2, value = "/b/two", detail = { path = "/b/two" } },
    })
  end)
end)
