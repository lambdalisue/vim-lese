local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

t.describe("builtin.source.history", function()
  t.it("emits the history of the mode from the newest entry", function()
    host.fn.histadd("input", "lese-first")
    host.fn.histadd("input", "lese-second")
    local items = t.collect(builtin.source.history({ mode = "input" }))
    t.eq(t.values(items), { "lese-second", "lese-first" })
    local histnr = host.fn.histnr("input")
    t.eq(items[1].detail, {
      history = { line = "lese-second", mode = "input", index = histnr, histnr = histnr },
    })
    t.ok(items[1].id ~= items[2].id)
  end)

  t.it("reads the command-line history by default", function()
    host.fn.histadd("cmd", "lese-cmd")
    local items = t.collect(builtin.source.history())
    t.eq(items[1].value, "lese-cmd")
    t.eq(items[1].detail.history.mode, "cmd")
  end)
end)
