-- Runs test files inside the host that loaded it, so the same tests run on
-- Neovim and on Vim (+lua). Assertions live in lese.testing.

local M = {}

local scope = {}
local cases = {}

---@param name string
---@param fn fun()
function M.describe(name, fn)
  scope[#scope + 1] = name
  fn()
  scope[#scope] = nil
end

---@param name string
---@param fn fun()
function M.it(name, fn)
  local parts = {}
  for i, s in ipairs(scope) do
    parts[i] = s
  end
  parts[#parts + 1] = name
  cases[#cases + 1] = { name = table.concat(parts, " "), fn = fn }
end

local function host_label(host)
  if not host then
    local jit = package.loaded.jit
    return "lua (" .. (jit and jit.version or _VERSION) .. ")"
  end
  if host.is_nvim then
    return "nvim"
  end
  local jit = package.loaded.jit
  return "vim (" .. (jit and jit.version or _VERSION) .. ")"
end

---@class lese.RunnerOptions
---@field dirs? string[]      -- directories searched for *_test.lua, default { "test" }
---@field files? string[]     -- test files to run instead of searching `dirs`
---@field filter? string      -- run only the tests whose full name contains it
---@field out? file*

---Load every *_test.lua, run its cases, report TAP-like lines and return the
---number of failures.
---@param opts? lese.RunnerOptions
---@return integer failed
function M.run(opts)
  opts = opts or {}
  -- Without an editor (a bare Lua running lese.core tests) there is no host.
  local host = require("lese.core.compat").in_editor() and require("lese.host") or nil
  local out = opts.out or io.stdout
  local filter = opts.filter
  if filter == "" then
    filter = nil
  end
  local files = {}
  if opts.files then
    for i, path in ipairs(opts.files) do
      files[i] = path
    end
  else
    local editor = assert(host, "searching dirs needs an editor")
    for _, dir in ipairs(opts.dirs or { "test" }) do
      for _, path in ipairs(editor.fn.globpath(dir, "**/*_test.lua", false, true)) do
        files[#files + 1] = path
      end
    end
  end
  table.sort(files)

  cases = {}
  for _, path in ipairs(files) do
    local chunk, err = loadfile(path)
    if not chunk then
      error(err, 0)
    end
    chunk()
  end

  local passed, failed = 0, 0
  for _, case in ipairs(cases) do
    if not filter or string.find(case.name, filter, 1, true) then
      local ok, err = xpcall(case.fn, function(e)
        if type(e) == "table" and e.message then
          return e.message
        end
        return debug.traceback(tostring(e), 2)
      end)
      if ok then
        passed = passed + 1
        out:write("ok - ", case.name, "\n")
      else
        failed = failed + 1
        out:write("not ok - ", case.name, "\n")
        for line in string.gmatch(tostring(err), "[^\n]+") do
          out:write("  # ", line, "\n")
        end
      end
    end
  end
  out:write(string.format("# %s: %d passed, %d failed\n", host_label(host), passed, failed))
  return failed
end

---Run the tests and quit the host with a status that tells whether they passed.
---Reads TEST_FILTER from the environment.
---@param opts? lese.RunnerOptions
function M.main(opts)
  opts = opts or {}
  if opts.filter == nil then
    opts.filter = os.getenv("TEST_FILTER")
  end
  local host = require("lese.core.compat").in_editor() and require("lese.host") or nil
  local out = io.stdout
  local ok, result = pcall(M.run, opts)
  local status = 0
  if not ok then
    out:write("not ok - test runner\n  # ", tostring(result), "\n")
    status = 2
  elseif result > 0 then
    status = 1
  end
  out:flush()
  if not host then
    os.exit(status)
  elseif status == 0 then
    host.cmd("qall!")
  else
    host.cmd("cquit " .. status)
  end
end

return M
