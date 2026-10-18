local t = require("lese.testing")
local builtin = require("lese.builtin")

t.describe("builtin.source.noop", function()
  t.it("emits nothing", function()
    t.eq(t.collect(builtin.source.noop()), {})
  end)
end)
