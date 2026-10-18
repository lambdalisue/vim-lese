local t = require("lese.testing")
local host = require("lese.host")
local relative_path = require("lese.builtin.renderer.relative_path")
local absolute_path = require("lese.builtin.renderer.absolute_path")

t.describe("builtin.renderer path renderers", function()
  t.it("take the current directory as the base by default", function()
    local cwd = host.fn.getcwd()
    local sep = host.fn.has("win32") == 1 and "\\" or "/"
    local path = cwd .. sep .. "a.lua"
    local relative = t.render(relative_path(), { t.item(path, { path = path }) })[1]
    t.eq(relative.label, "a.lua")
    local absolute = t.render(absolute_path(), { t.item("a.lua", { path = "a.lua" }) })[1]
    t.eq(absolute.label, path)
  end)
end)
