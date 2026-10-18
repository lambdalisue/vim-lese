local t = require("lese.testing")
local builtin = require("lese.builtin")

t.describe("builtin.source.list", function()
  t.it("emits the items it was given", function()
    local items = t.items({ "a", "b" })
    t.eq(t.collect(builtin.source.list(items)), items)
  end)
end)
