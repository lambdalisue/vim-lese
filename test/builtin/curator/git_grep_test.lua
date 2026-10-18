local t = require("lese.testing")
local host = require("lese.host")
local path = require("lese.builtin._path")
local builtin = require("lese.builtin")

-- Load the module and the job helpers before a test changes the current
-- directory, which package.path and the relative 'runtimepath' depend on.
local git_grep = builtin.curator.git_grep
host.cmd("runtime autoload/lese/internal.vim")

local sep = path.separator(host)

local function repository()
  local root = path.strip_trailing(host.fn.fnamemodify(host.fn.tempname(), ":p"))
  host.fn.mkdir(path.join(root, "sub", sep), "p")
  host.fn.writefile({ "hello world" }, path.join(root, "a.txt", sep))
  host.fn.writefile({ "nothing", "say hello" }, path.join(root, "sub" .. sep .. "b.txt", sep))
  host.fn.system({ "git", "-C", root, "init", "-q" })
  host.fn.system({ "git", "-C", root, "add", "." })
  return root
end

local function in_directory(dir, fn)
  local saved = host.fn.getcwd()
  host.cmd("cd " .. host.fn.fnameescape(dir))
  local ok, result = pcall(fn)
  host.cmd("cd " .. host.fn.fnameescape(saved))
  if not ok then
    error(result, 0)
  end
  return result
end

t.describe("builtin.curator.git_grep", function()
  t.it("emits each match in the repository with an absolute path", function()
    if host.fn.executable("git") == 0 then
      return
    end
    local root = repository()
    local items = in_directory(root, function()
      return t.curate(git_grep(), { query = "hello" })
    end)
    table.sort(items, function(a, b)
      return a.value < b.value
    end)
    local cwd = in_directory(root, host.fn.getcwd)
    local a = path.join(cwd, "a.txt", sep)
    local b = path.join(cwd, "sub" .. sep .. "b.txt", sep)
    t.eq(t.values(items), { a .. ":1:1:hello world", b .. ":2:5:say hello" })
    t.eq(items[2].detail, { path = b, line = 2, column = 5, context = "say hello" })
  end)

  t.it("searches below the current directory with paths from it", function()
    if host.fn.executable("git") == 0 then
      return
    end
    local root = repository()
    local sub = path.join(root, "sub", sep)
    local items = in_directory(sub, function()
      return t.curate(git_grep(), { query = "hello" })
    end)
    local cwd = in_directory(sub, host.fn.getcwd)
    t.eq(t.values(items), { path.join(cwd, "b.txt", sep) .. ":2:5:say hello" })
  end)
end)
