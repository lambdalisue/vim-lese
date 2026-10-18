local t = require("lese.testing")
local host = require("lese.host")
local path = require("lese.builtin._path")
local builtin = require("lese.builtin")

local sep = path.separator(host)

local function tree()
  local root = path.strip_trailing(host.fn.fnamemodify(host.fn.tempname(), ":p"))
  host.fn.mkdir(path.join(root, "sub", sep), "p")
  host.fn.writefile({ "Hello world", "bye" }, path.join(root, "a.txt", sep))
  host.fn.writefile({ "nothing", "say hello" }, path.join(root, "sub" .. sep .. "b.lua", sep))
  return root
end

local function sorted(values)
  table.sort(values)
  return values
end

t.describe("builtin.curator.rg", function()
  t.it("emits each match with its line and column", function()
    if host.fn.executable("rg") == 0 then
      return
    end
    local root = tree()
    local b = path.join(root, "sub" .. sep .. "b.lua", sep)
    local items = t.curate(builtin.curator.rg(), { args = { root }, query = "hello" })
    t.eq(t.values(items), { b .. ":2:5:say hello" })
    t.eq(items[1].detail, { path = b, line = 2, column = 5, context = "say hello" })
  end)

  t.it("passes the options as flags", function()
    if host.fn.executable("rg") == 0 then
      return
    end
    local root = tree()
    local curator = builtin.curator.rg({ ignore_case = true, glob = { "*.txt" } })
    local items = t.curate(curator, { args = { root }, query = "hello" })
    t.eq(t.values(items), { path.join(root, "a.txt", sep) .. ":1:1:Hello world" })
  end)

  t.it("shows the path relative to the base with relative_from_base", function()
    if host.fn.executable("rg") == 0 then
      return
    end
    local root = tree()
    local curator = builtin.curator.rg({ relative_from_base = true, smart_case = true })
    local items = t.curate(curator, { args = { root }, query = "hello" })
    t.eq(
      sorted(t.values(items)),
      sorted({ "a.txt:1:1:Hello world", "sub" .. sep .. "b.lua:2:5:say hello" })
    )
  end)
end)
