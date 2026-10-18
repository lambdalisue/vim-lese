local t = require("lese.testing")
local host = require("lese.host")
local path = require("lese.builtin._path")
local builtin = require("lese.builtin")

-- Load the module before a test replaces 'runtimepath', which Neovim loads Lua from.
local helptag = builtin.previewer.helptag

local sep = path.separator(host)

local function with_runtime(files, fn)
  local root = path.strip_trailing(host.fn.fnamemodify(host.fn.tempname(), ":p"))
  local doc = path.join(root, "doc", sep)
  host.fn.mkdir(doc, "p")
  for name, lines in pairs(files) do
    host.fn.writefile(lines, path.join(doc, name, sep))
  end
  local saved = host.eval("&runtimepath")
  host.cmd("let &runtimepath = " .. host.fn.string(root))
  local ok, result = pcall(fn)
  host.cmd("let &runtimepath = " .. host.fn.string(saved))
  if not ok then
    error(result, 0)
  end
  return result
end

t.describe("builtin.previewer.helptag", function()
  t.it("shows the help file with the cursor on the tag", function()
    local lines = { "*sample.txt*  Sample", "", "Intro  *sample-intro*", "text" }
    local result = with_runtime({ ["sample.txt"] = lines }, function()
      return t.preview(
        helptag(),
        t.item("sample-intro", { helptag = "sample-intro", helpfile = "sample.txt" })
      )
    end)
    t.eq(result, { content = lines, filetype = "help", line = 3 })
  end)

  t.it("shows the file from the top when the tag is not in it", function()
    local result = with_runtime({ ["sample.txt"] = { "nothing" } }, function()
      return t.preview(helptag(), t.item("x", { helptag = "absent", helpfile = "sample.txt" }))
    end)
    t.eq(result, { content = { "nothing" }, filetype = "help" })
  end)

  t.it("shows nothing when the help file is missing", function()
    local result = with_runtime({}, function()
      return t.preview(helptag(), t.item("x", { helptag = "x", helpfile = "missing.txt" }))
    end)
    t.eq(result, nil)
  end)
end)
