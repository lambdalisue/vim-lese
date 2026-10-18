local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

-- Load the actions and the message helper before a test changes the current
-- directory, which package.path and the relative 'runtimepath' depend on.
local cd = builtin.action.cd
local defaults = builtin.action.default_cd_actions
host.cmd("runtime autoload/lese/internal.vim")

local function restoring_cwd(fn)
  local saved = host.fn.getcwd()
  local ok, err = pcall(fn)
  host.cmd("lcd " .. host.fn.fnameescape(saved))
  host.cmd("cd " .. host.fn.fnameescape(saved))
  if not ok then
    error(err, 0)
  end
end

local function directory()
  local dir = host.fn.resolve(host.fn.fnamemodify(host.fn.tempname(), ":p"))
  host.fn.mkdir(dir, "p")
  return host.fn.fnamemodify(dir, ":p:h")
end

t.describe("builtin.action.cd", function()
  t.it("changes to detail.path when it is a directory", function()
    local dir = directory()
    restoring_cwd(function()
      t.invoke(cd(), { item = t.item("x", { path = dir }) })
      t.eq(host.fn.getcwd(), dir)
    end)
  end)

  t.it("changes to the parent of a file", function()
    local dir = directory()
    local file = dir .. "/f.txt"
    host.fn.writefile({ "x" }, file)
    restoring_cwd(function()
      t.invoke(cd(), { item = t.item("x", { bufname = file }) })
      t.eq(host.fn.getcwd(), dir)
    end)
  end)

  t.it("changes the window's directory with lcd", function()
    local dir = directory()
    restoring_cwd(function()
      t.invoke(cd({ command = "lcd" }), { item = t.item("x", { path = dir }) })
      t.eq(host.fn.haslocaldir(), 1)
      t.eq(host.fn.getcwd(), dir)
    end)
  end)
end)

t.describe("builtin.action.default_cd_actions", function()
  t.it("holds cd, lcd and tcd", function()
    local names = {}
    for name in pairs(defaults) do
      names[#names + 1] = name
    end
    table.sort(names)
    t.eq(names, { "cd", "lcd", "tcd" })
  end)
end)
