local t = require("lese.testing")
local nerdfont = require("lese.builtin.renderer.nerdfont")
local icons = require("lese.builtin._nerdfont")

local function render(path)
  local item = t.item(path, { path = path })
  item.decorations = { { column = 1, length = 1 } }
  return t.render(nerdfont(), { item })[1]
end

t.describe("builtin.renderer.nerdfont", function()
  t.it("is named builtin.renderer.nerdfont", function()
    t.eq(nerdfont().name, "builtin.renderer.nerdfont")
  end)

  t.it("puts the icon of the extension and two spaces before the label", function()
    t.eq(render("src/main.lua").label, icons.extension.lua .. "  src/main.lua")
  end)

  t.it("moves the decorations past the icon", function()
    local prefix = icons.extension.lua .. "  "
    t.eq(render("main.lua").decorations, { { column = #prefix + 1, length = 1 } })
  end)

  t.it("looks the extension up in lower case", function()
    t.eq(render("MAIN.LUA").label, icons.extension.lua .. "  MAIN.LUA")
  end)

  t.it("prefers the file name over the extension", function()
    t.eq(render("a/Makefile").label, icons.basename.makefile .. "  a/Makefile")
  end)

  t.it("prefers a pattern over the file name", function()
    t.eq(render("types/index.d.ts").label, icons.pattern[1][2] .. "  types/index.d.ts")
  end)

  t.it("falls back to the default icon", function()
    t.eq(render("unknown.zzz").label, icons.extension["."] .. "  unknown.zzz")
    t.eq(render(".hidden-zzz").label, icons.extension["."] .. "  .hidden-zzz")
  end)
end)
