local t = require("lese.testing")
local host = require("lese.host")
local path = require("lese.builtin._path")
local builtin = require("lese.builtin")

-- Load the module before a test replaces 'runtimepath', which Neovim loads Lua from.
local helptag = builtin.source.helptag

local sep = path.separator(host)

local function runtime(files)
  local root = path.strip_trailing(host.fn.fnamemodify(host.fn.tempname(), ":p"))
  local doc = path.join(root, "doc", sep)
  host.fn.mkdir(doc, "p")
  for name, lines in pairs(files) do
    host.fn.writefile(lines, path.join(doc, name, sep))
  end
  return root
end

local function with_runtimepath(dirs, fn)
  local saved = host.eval("&runtimepath")
  host.cmd("let &runtimepath = " .. host.fn.string(table.concat(dirs, ",")))
  local ok, err = pcall(fn)
  host.cmd("let &runtimepath = " .. host.fn.string(saved))
  if not ok then
    error(err, 0)
  end
end

t.describe("builtin.source.helptag", function()
  t.it("emits the tags of every doc/tags file on 'runtimepath'", function()
    local a = runtime({
      tags = { "!_TAG_FILE_ENCODING\tutf-8\t//", "alpha\talpha.txt\t/*alpha*", "" },
    })
    local b = runtime({ tags = { "beta\tbeta.txt\t/*beta*" } })
    local items
    with_runtimepath({ a, b }, function()
      items = t.collect(helptag())
    end)
    t.eq(t.values(items), { "alpha", "beta" })
    t.eq(items[1].detail, { helptag = "alpha", helpfile = "alpha.txt" })
    t.ok(items[1].id ~= items[2].id)
  end)

  t.it("emits a tag once, from the first directory that has it", function()
    local a = runtime({ tags = { "alpha\ta.txt\t/*alpha*" } })
    local b = runtime({ tags = { "alpha\tb.txt\t/*alpha*" } })
    local items
    with_runtimepath({ a, b }, function()
      items = t.collect(helptag())
    end)
    t.eq(#items, 1)
    t.eq(items[1].detail.helpfile, "a.txt")
  end)

  t.it("reads translated tags files with their language", function()
    local a = runtime({
      tags = { "alpha\talpha.txt\t/*alpha*" },
      ["tags-ja"] = { "alpha\talpha.jax\t/*alpha*" },
      ["tagsfoo"] = { "ignored\tx.txt\t/*ignored*" },
    })
    local items
    with_runtimepath({ a }, function()
      items = t.collect(helptag())
    end)
    table.sort(items, function(x, y)
      return x.detail.helpfile < y.detail.helpfile
    end)
    t.eq(#items, 2)
    t.eq(items[1].detail, { helptag = "alpha", helpfile = "alpha.jax", lang = "ja" })
    t.eq(items[2].detail, { helptag = "alpha", helpfile = "alpha.txt" })
  end)
end)
