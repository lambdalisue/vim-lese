local t = require("lese.testing")
local host = require("lese.host")
local path = require("lese.builtin._path")
local builtin = require("lese.builtin")

local sep = path.separator(host)
local base = sep == "/" and "/base" or "C:\\base"

t.describe("builtin.refiner.absolute_path", function()
  t.it("joins a relative path to the base in value and detail.abspath", function()
    local p = "a" .. sep .. "b.txt"
    local item = t.item(p .. ":1:text", { path = p })
    local refined = t.refine(builtin.refiner.absolute_path({ base = base }), item)
    local abspath = path.join(base, p, sep)
    t.eq(refined, {
      id = item.id,
      value = abspath .. ":1:text",
      detail = { path = p, abspath = abspath },
    })
  end)

  t.it("keeps an absolute path", function()
    local p = path.join(base, "x.txt", sep)
    local refined = t.refine(builtin.refiner.absolute_path(), t.item(p, { path = p }))
    ---@cast refined -nil
    t.eq(refined.value, p)
    t.eq(refined.detail.abspath, p)
  end)

  t.it("joins to the current directory by default", function()
    local refined = t.refine(builtin.refiner.absolute_path(), t.item("x", { path = "x" }))
    ---@cast refined -nil
    t.eq(refined.value, path.join(host.fn.getcwd(), "x", sep))
  end)

  t.it("leaves the item it was given untouched", function()
    local item = t.item("x", { path = "x" })
    t.refine(builtin.refiner.absolute_path({ base = base }), item)
    t.eq(item, t.item("x", { path = "x" }))
  end)
end)
