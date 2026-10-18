-- Every difference between Neovim's and Vim's Lua interface lives here, so the
-- rest of the plugin runs on either host unchanged. Reach `vim.*` beyond what
-- vim.yml declares only from this file.
--# selene: allow(incorrect_standard_library_use)

local M = {}

---True on Neovim, false on Vim (+lua).
M.is_nvim = vim.api ~= nil

if M.is_nvim then
  ---Call a Vim function.
  ---@param name string
  ---@return any
  function M.call(name, ...)
    return vim.call(name, ...)
  end

  ---Run an Ex command.
  ---@param command string
  function M.cmd(command)
    vim.cmd(command)
  end

  return M
end

-- Vim does not convert a plain Lua table passed to a Vim function, and returns
-- lists and dicts as userdata, so values are converted at the boundary.

-- PUC Lua 5.2 and later only have table.unpack.
local unpack = unpack or table.unpack

local function to_vim(value)
  if type(value) ~= "table" then
    return value
  end
  -- An empty table becomes a list, as on Neovim.
  if next(value) == nil or value[1] ~= nil then
    local list = vim.list()
    for _, item in ipairs(value) do
      list:add(to_vim(item))
    end
    return list
  end
  local dict = vim.dict()
  for k, item in pairs(value) do
    dict[tostring(k)] = to_vim(item)
  end
  return dict
end

local function from_vim(value)
  local kind = vim.type(value)
  if kind == "list" then
    local result = {}
    for i = 1, #value do
      result[i] = from_vim(value[i])
    end
    return result
  elseif kind == "dict" then
    local result = {}
    for k, item in value() do
      result[k] = from_vim(item)
    end
    return result
  end
  return value
end

---Call a Vim function.
---@param name string
---@return any
function M.call(name, ...)
  local args = { ... }
  for i = 1, select("#", ...) do
    args[i] = to_vim(args[i])
  end
  return from_vim(vim.call(name, unpack(args, 1, select("#", ...))))
end

---Run an Ex command.
---@param command string
function M.cmd(command)
  vim.command(command)
end

return M
