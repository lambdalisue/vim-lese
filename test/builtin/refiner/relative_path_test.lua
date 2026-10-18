local t = require("lese.testing")
local host = require("lese.host")
local path = require("lese.builtin._path")
local builtin = require("lese.builtin")

local sep = path.separator(host)
local base = sep == "/" and "/base" or "C:\\base"

t.describe("builtin.refiner.relative_path", function()
  t.it("makes the path relative to the base in value and detail.relpath", function()
    local p = path.join(base, "a" .. sep .. "b.txt", sep)
    local item = t.item(p .. ":1:text", { path = p, line = 1 })
    local refined = t.refine(builtin.refiner.relative_path({ base = base }), item)
    local relpath = "a" .. sep .. "b.txt"
    t.eq(refined, {
      id = item.id,
      value = relpath .. ":1:text",
      detail = { path = p, line = 1, relpath = relpath },
    })
  end)

  t.it("climbs out of the base for a path outside it", function()
    local p = path.join(base .. "2", "c.txt", sep)
    local refined =
      t.refine(builtin.refiner.relative_path({ base = base }), t.item(p, { path = p }))
    ---@cast refined -nil
    t.eq(refined.value, ".." .. sep .. "base2" .. sep .. "c.txt")
  end)

  t.it("is relative to the current directory by default", function()
    local p = path.join(host.fn.getcwd(), "x.txt", sep)
    local refined = t.refine(builtin.refiner.relative_path(), t.item(p, { path = p }))
    ---@cast refined -nil
    t.eq(refined.value, "x.txt")
  end)
end)
