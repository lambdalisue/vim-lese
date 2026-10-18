-- Library functions whose name differs between Lua 5.1 and later versions.

local M = {}

-- PUC Lua 5.2 and later only have table.unpack.
---@diagnostic disable-next-line: deprecated
M.unpack = unpack or rawget(table, "unpack")

---Pack the arguments into a table with their count in `n`.
---@return table
function M.pack(...)
  local packed = { ... } ---@type table
  packed.n = select("#", ...)
  return packed
end

return M
