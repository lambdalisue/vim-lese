local t = require("lese.testing")
local host = require("lese.host")
local path = require("lese.builtin._path")
local builtin = require("lese.builtin")

local sep = path.separator(host)

local function tree()
  local root = path.strip_trailing(host.fn.fnamemodify(host.fn.tempname(), ":p"))
  host.fn.mkdir(path.join(root, "sub", sep), "p")
  host.fn.writefile({ "hello world", "bye" }, path.join(root, "a.txt", sep))
  host.fn.writefile({ "nothing", "hello: again" }, path.join(root, "sub" .. sep .. "b.txt", sep))
  return root
end

local function by_value(items)
  table.sort(items, function(a, b)
    return a.value < b.value
  end)
  return items
end

local function sorted(values)
  table.sort(values)
  return values
end

t.describe("builtin.curator.grep", function()
  t.it("emits each matching line under the directory given as the first argument", function()
    if host.fn.executable("grep") == 0 then
      return
    end
    local root = tree()
    local a = path.join(root, "a.txt", sep)
    local b = path.join(root, "sub" .. sep .. "b.txt", sep)
    local items = by_value(t.curate(builtin.curator.grep(), { args = { root }, query = "hello" }))
    t.eq(t.values(items), sorted({ a .. ":1:hello world", b .. ":2:hello: again" }))
    local first = items[1].value == a .. ":1:hello world" and items[1] or items[2]
    t.eq(first.detail, { path = a, line = 1, context = "hello world" })
    t.ok(items[1].id ~= items[2].id)
  end)

  t.it("shows the path relative to the base with relative_from_base", function()
    if host.fn.executable("grep") == 0 then
      return
    end
    local root = tree()
    local curator = builtin.curator.grep({ relative_from_base = true })
    local items = t.curate(curator, { args = { root }, query = "bye" })
    t.eq(t.values(items), { "a.txt:2:bye" })
    t.eq(items[1].detail.path, path.join(root, "a.txt", sep))
  end)

  t.it("emits nothing when no line matches", function()
    if host.fn.executable("grep") == 0 then
      return
    end
    t.eq(t.curate(builtin.curator.grep(), { args = { tree() }, query = "absent" }), {})
  end)
end)
