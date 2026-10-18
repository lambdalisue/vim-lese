local t = require("lese.testing")
local noop = require("lese.builtin.sorter.noop")

t.describe("builtin.sorter.noop", function()
  t.it("keeps the order", function()
    t.eq(t.values(t.sort(noop(), t.items({ "b", "a" }))), { "b", "a" })
  end)
end)
