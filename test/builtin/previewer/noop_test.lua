local t = require("lese.testing")
local builtin = require("lese.builtin")

t.describe("builtin.previewer.noop", function()
  t.it("shows nothing", function()
    t.eq(t.preview(builtin.previewer.noop(), t.item("a")), nil)
  end)
end)
