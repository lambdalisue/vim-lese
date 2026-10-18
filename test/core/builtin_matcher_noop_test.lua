local t = require("lese.testing")
local noop = require("lese.builtin.matcher.noop")

t.describe("builtin.matcher.noop", function()
  t.it("emits nothing", function()
    t.eq(t.match(noop(), { query = "", items = t.items({ "a", "b" }) }), {})
  end)
end)
