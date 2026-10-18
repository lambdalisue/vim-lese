local t = require("lese.testing")
local smart_path = require("lese.builtin.renderer.smart_path")

local function render(value, decorations)
  local item = t.item(value)
  item.decorations = decorations or {}
  return t.render(smart_path(), { item })[1]
end

t.describe("builtin.renderer.smart_path", function()
  t.it("is named builtin.renderer.smart_path", function()
    t.eq(smart_path().name, "builtin.renderer.smart_path")
  end)

  t.it("shows the file name first and the directory dimmed after it", function()
    local item = render("src/lese/init.lua")
    t.eq(item.label, "init.lua src/lese")
    t.eq(item.decorations, { { column = 9, length = 9, highlight = "Comment" } })
  end)

  t.it("leaves a label without a directory alone", function()
    local item = render("init.lua", { { column = 1, length = 4 } })
    t.eq(item.label, "init.lua")
    t.eq(item.decorations, { { column = 1, length = 4 } })
  end)

  t.it("moves decorations with the part they are on", function()
    -- "src/init.lua": "src" at 1, "init" at 5
    local item = render("src/init.lua", { { column = 1, length = 3 }, { column = 5, length = 4 } })
    t.eq(item.label, "init.lua src")
    t.eq(item.decorations, {
      { column = 10, length = 3 },
      { column = 1, length = 4 },
      { column = 9, length = 4, highlight = "Comment" },
    })
  end)

  t.it("splits a decoration across the separator and drops the separator", function()
    -- "ab/cd" with "b/c" decorated
    local item = render("ab/cd", { { column = 2, length = 3 } })
    t.eq(item.label, "cd ab")
    t.eq(item.decorations, {
      { column = 5, length = 1 },
      { column = 1, length = 1 },
      { column = 3, length = 3, highlight = "Comment" },
    })
  end)

  t.it("counts bytes in a multibyte file name", function()
    local item = render("dir/あ.txt")
    t.eq(item.label, "あ.txt dir")
    t.eq(item.decorations, { { column = 8, length = 4, highlight = "Comment" } })
  end)
end)
