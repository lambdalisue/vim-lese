-- The test API for lese and its extensions. The same tests run on Neovim and
-- on Vim (+lua): start them with lese.testing.runner.

local runner = require("lese.testing.runner")
local inspect = require("lese.testing.inspect")

local M = {}

M.describe = runner.describe
M.it = runner.it
M.inspect = inspect

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

local function fail(message, level)
  -- selene: allow(incorrect_standard_library_use)
  error({ message = message .. "\n" .. debug.traceback("", level + 1) }, level + 1)
end

---Assert that two values are equal, comparing tables by content.
---@param actual any
---@param expected any
---@param message? string
function M.eq(actual, expected, message)
  if not deep_equal(actual, expected) then
    fail(
      (message and message .. "\n" or "")
        .. "expected: "
        .. inspect(expected)
        .. "\n  actual: "
        .. inspect(actual),
      2
    )
  end
end

---Assert that a value is truthy.
---@param value any
---@param message? string
function M.ok(value, message)
  if not value then
    fail(message or ("expected a truthy value, got " .. inspect(value)), 2)
  end
end

---Assert that `fn` raises an error, whose message contains `text` when given.
---@param fn fun()
---@param text? string
---@return string message
function M.raises(fn, text)
  local ok, err = pcall(fn)
  if ok then
    fail("expected an error, but none was raised", 2)
  end
  local message = type(err) == "table" and (err.message or inspect(err)) or tostring(err)
  if text and not string.find(message, text, 1, true) then
    fail("expected an error containing " .. inspect(text) .. ", got " .. inspect(message), 2)
  end
  return message
end

return M
