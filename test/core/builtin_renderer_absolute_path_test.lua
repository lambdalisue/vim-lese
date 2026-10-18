local t = require("lese.testing")
local absolute_path = require("lese.builtin.renderer.absolute_path")

local function render(path, decorations)
  local item = t.item(path, { path = path })
  item.decorations = decorations or {}
  return t.render(absolute_path({ base = "/home/me" }), { item })[1]
end

t.describe("builtin.renderer.absolute_path", function()
  t.it("is named builtin.renderer.absolute_path", function()
    t.eq(absolute_path().name, "builtin.renderer.absolute_path")
  end)

  t.it("joins a relative path to the base", function()
    t.eq(render("src/a.lua").label, "/home/me/src/a.lua")
  end)

  t.it("leaves an absolute path alone", function()
    t.eq(render("/etc/hosts").label, "/etc/hosts")
  end)

  t.it("moves decorations with the path", function()
    t.eq(
      render("a.lua", { { column = 1, length = 1 } }).decorations,
      { { column = 10, length = 1 } }
    )
  end)
end)
