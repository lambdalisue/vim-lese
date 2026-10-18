local t = require("lese.testing")
local builtin = require("lese.builtin")

t.describe("builtin.action.noop", function()
  t.it("does nothing", function()
    t.eq(t.invoke(builtin.action.default_noop_actions.noop, { item = t.item("a") }), nil)
  end)
end)
