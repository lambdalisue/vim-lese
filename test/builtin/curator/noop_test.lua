local t = require("lese.testing")
local builtin = require("lese.builtin")

t.describe("builtin.curator.noop", function()
  t.it("emits nothing", function()
    t.eq(t.curate(builtin.curator.noop(), { query = "a" }), {})
  end)
end)
