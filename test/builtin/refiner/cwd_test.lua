local t = require("lese.testing")
local host = require("lese.host")
local path = require("lese.builtin._path")
local builtin = require("lese.builtin")

local sep = path.separator(host)

t.describe("builtin.refiner.cwd", function()
  t.it("keeps items whose path is under the current directory", function()
    local p = path.join(host.fn.getcwd(), "a" .. sep .. "b.txt", sep)
    local item = t.item(p, { path = p })
    t.eq(t.refine(builtin.refiner.cwd(), item), item)
  end)

  t.it("drops items whose path is elsewhere", function()
    local p = sep == "/" and "/elsewhere/x" or "Z:\\elsewhere\\x"
    t.eq(t.refine(builtin.refiner.cwd(), t.item(p, { path = p })), nil)
  end)

  t.it("drops a sibling whose name starts with the current directory's", function()
    local p = host.fn.getcwd() .. "-sibling" .. sep .. "x"
    t.eq(t.refine(builtin.refiner.cwd(), t.item(p, { path = p })), nil)
  end)
end)
