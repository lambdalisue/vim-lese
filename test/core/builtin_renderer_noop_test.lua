local t = require("lese.testing")
local noop = require("lese.builtin.renderer.noop")

t.describe("builtin.renderer.noop", function()
  t.it("leaves the label as the value", function()
    t.eq(t.render(noop(), t.items({ "a" }))[1].label, "a")
  end)
end)
