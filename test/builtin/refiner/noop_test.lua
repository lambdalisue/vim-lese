local t = require("lese.testing")
local builtin = require("lese.builtin")

t.describe("builtin.refiner.noop", function()
  t.it("passes the item through unchanged", function()
    local item = t.item("a", { path = "a" })
    t.eq(t.refine(builtin.refiner.noop(), item), item)
  end)
end)
