local t = require("lese.testing")
local relative_path = require("lese.builtin.renderer.relative_path")

local function render(path, label, decorations, base)
  local item = t.item(path, { path = path })
  item.label = label or path
  item.decorations = decorations or {}
  return t.render(relative_path({ base = base or "/home/me/project" }), { item })[1]
end

t.describe("builtin.renderer.relative_path", function()
  t.it("is named builtin.renderer.relative_path", function()
    t.eq(relative_path().name, "builtin.renderer.relative_path")
  end)

  t.it("shows a path under the base relative to it", function()
    t.eq(render("/home/me/project/src/a.lua").label, "src/a.lua")
  end)

  t.it("climbs out of the base with ..", function()
    t.eq(render("/home/me/other/a.lua").label, "../other/a.lua")
  end)

  t.it("ignores a trailing separator on the base", function()
    t.eq(render("/home/me/project/a.lua", nil, nil, "/home/me/project/").label, "a.lua")
  end)

  t.it("leaves a relative path alone", function()
    t.eq(render("src/a.lua").label, "src/a.lua")
  end)

  t.it("rewrites the path where it appears in the label", function()
    t.eq(render("/home/me/project/a.lua", "> /home/me/project/a.lua:3").label, "> a.lua:3")
  end)

  t.it("keeps decorations on the same characters", function()
    -- "a.lua" is decorated at the end of the path; ":3" after it
    local item = render("/home/me/project/a.lua", "/home/me/project/a.lua:3", {
      { column = 18, length = 1 },
      { column = 23, length = 2 },
    })
    t.eq(item.label, "a.lua:3")
    t.eq(item.decorations, { { column = 1, length = 1 }, { column = 6, length = 2 } })
  end)

  t.it("drops decorations on the part of the path that is gone", function()
    local item = render("/home/me/project/a.lua", nil, { { column = 2, length = 4 } })
    t.eq(item.decorations, {})
  end)

  t.it("trims a decoration that runs into the part that is gone", function()
    local item = render("/home/me/project/a.lua", nil, { { column = 15, length = 5 } })
    t.eq(item.decorations, { { column = 1, length = 2 } })
  end)
end)
