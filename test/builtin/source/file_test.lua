local t = require("lese.testing")
local host = require("lese.host")
local path = require("lese.builtin._path")
local builtin = require("lese.builtin")

local sep = path.separator(host)

local function tree()
  local root = path.strip_trailing(host.fn.fnamemodify(host.fn.tempname(), ":p"))
  host.fn.mkdir(path.join(root, "sub", sep), "p")
  host.fn.mkdir(path.join(root, "skip", sep), "p")
  host.fn.writefile({ "a" }, path.join(root, "a.txt", sep))
  host.fn.writefile({ "b" }, path.join(root, "sub" .. sep .. "b.txt", sep))
  host.fn.writefile({ "c" }, path.join(root, "skip" .. sep .. "c.txt", sep))
  host.fn.writefile({ "h" }, path.join(root, ".hidden", sep))
  return root
end

local function sorted(values)
  table.sort(values)
  return values
end

t.describe("builtin.source.file", function()
  t.it("emits every file under the directory given as the first argument", function()
    local root = tree()
    local items = t.collect(builtin.source.file(), { args = { root } })
    t.eq(
      sorted(t.values(items)),
      sorted({
        path.join(root, ".hidden", sep),
        path.join(root, "a.txt", sep),
        path.join(root, "skip" .. sep .. "c.txt", sep),
        path.join(root, "sub" .. sep .. "b.txt", sep),
      })
    )
  end)

  t.it("puts the absolute path in detail.path and gives each item its own id", function()
    local root = tree()
    local items = t.collect(builtin.source.file(), { args = { root } })
    local ids = {}
    for _, item in ipairs(items) do
      t.eq(item.detail.path, item.value)
      t.ok(not ids[item.id], "duplicated id " .. tostring(item.id))
      ids[item.id] = true
    end
  end)

  t.it("skips files and directories the filters reject", function()
    local root = tree()
    local source = builtin.source.file({
      filter_file = function(p)
        return not p:find("%.hidden$")
      end,
      filter_directory = function(p)
        return not p:find("skip$")
      end,
    })
    local items = t.collect(source, { args = { root } })
    t.eq(
      sorted(t.values(items)),
      sorted({
        path.join(root, "a.txt", sep),
        path.join(root, "sub" .. sep .. "b.txt", sep),
      })
    )
  end)

  t.it("shows the path relative to the base with relative_from_base", function()
    local root = tree()
    local items = t.collect(builtin.source.file({ relative_from_base = true }), { args = { root } })
    t.eq(
      sorted(t.values(items)),
      sorted({ ".hidden", "a.txt", "skip" .. sep .. "c.txt", "sub" .. sep .. "b.txt" })
    )
    for _, item in ipairs(items) do
      t.ok(path.is_absolute(item.detail.path))
    end
  end)

  t.it("emits nothing for a directory that does not exist", function()
    local items = t.collect(builtin.source.file(), { args = { host.fn.tempname() } })
    t.eq(items, {})
  end)

  t.it("walks a directory reached through a symbolic link only once", function()
    if host.fn.has("win32") == 1 or host.fn.executable("ln") == 0 then
      return
    end
    local root = tree()
    host.fn.system({ "ln", "-s", root, path.join(root, "sub" .. sep .. "loop", sep) })
    local items = t.collect(builtin.source.file(), { args = { root } })
    t.eq(#items, 4)
  end)
end)
