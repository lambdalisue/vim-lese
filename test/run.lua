-- Runs every test/**/*_test.lua inside the host that loaded this file, so the
-- same tests run on Neovim and on Vim (+lua). Start it with `just test`.
--
-- A test file receives the test API as its chunk argument:
--
--   local t = ...
--   t.describe("thing", function()
--     t.it("does something", function()
--       t.eq(actual, expected)
--     end)
--   end)
--
-- TEST_FILTER, when set, runs only the tests whose full name contains it.
--
-- The runner meets each host directly, as lua/lese/host.lua does.
--# selene: allow(incorrect_standard_library_use)

local out = io.stdout
local is_nvim = vim.api ~= nil
local filter = os.getenv("TEST_FILTER")
if filter == "" then
  filter = nil
end

-- Ex commands go through a different function on each host.
local function ex(command)
  if is_nvim then
    vim.cmd(command)
  else
    vim.command(command)
  end
end

local function quit(code)
  out:flush()
  if code == 0 then
    ex("qall!")
  else
    ex("cquit " .. code)
  end
end

local function render(value, depth)
  depth = depth or 0
  if type(value) == "string" then
    return string.format("%q", value)
  end
  if type(value) ~= "table" or depth > 3 then
    return tostring(value)
  end
  local keys = {}
  for k in pairs(value) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = "[" .. render(k) .. "] = " .. render(value[k], depth + 1)
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

local function deep_equal(a, b)
  if type(a) ~= type(b) then
    return false
  end
  if type(a) ~= "table" then
    return a == b
  end
  for k, v in pairs(a) do
    if not deep_equal(v, b[k]) then
      return false
    end
  end
  for k in pairs(b) do
    if a[k] == nil then
      return false
    end
  end
  return true
end

local t = {}
local scope = {}
local cases = {}

function t.describe(name, fn)
  scope[#scope + 1] = name
  fn()
  scope[#scope] = nil
end

function t.it(name, fn)
  local parts = {}
  for i, s in ipairs(scope) do
    parts[i] = s
  end
  parts[#parts + 1] = name
  cases[#cases + 1] = { name = table.concat(parts, " "), fn = fn }
end

function t.eq(actual, expected, message)
  if not deep_equal(actual, expected) then
    error(
      (message and message .. "\n" or "")
        .. "expected: "
        .. render(expected)
        .. "\n  actual: "
        .. render(actual),
      2
    )
  end
end

function t.ok(value, message)
  if not value then
    error(message or ("expected a truthy value, got " .. render(value)), 2)
  end
end

function t.raises(fn, pattern)
  local ok, err = pcall(fn)
  if ok then
    error("expected an error, but none was raised", 2)
  end
  if pattern and not string.find(tostring(err), pattern) then
    error("expected an error matching " .. render(pattern) .. ", got " .. render(tostring(err)), 2)
  end
end

local function main()
  local files = {}
  for path in string.gmatch(vim.fn.globpath("test", "**/*_test.lua"), "[^\n]+") do
    files[#files + 1] = path
  end
  table.sort(files)

  for _, path in ipairs(files) do
    local chunk, err = loadfile(path)
    if not chunk then
      error(err, 0)
    end
    chunk(t)
  end

  local host = is_nvim and "nvim" or ("vim (" .. tostring(vim.lua_version) .. ")")
  local passed, failed = 0, 0
  for _, case in ipairs(cases) do
    if not filter or string.find(case.name, filter, 1, true) then
      local ok, err = pcall(case.fn)
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
  out:write(string.format("# %s: %d passed, %d failed\n", host, passed, failed))
  return failed == 0 and 0 or 1
end

local ok, result = pcall(main)
if not ok then
  out:write("not ok - test runner\n  # ", tostring(result), "\n")
  quit(2)
else
  quit(result)
end
