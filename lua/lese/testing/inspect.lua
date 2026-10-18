-- A stable, single-line rendering of Lua values for assertion messages.

local function inspect(value, depth)
  depth = depth or 0
  if type(value) == "string" then
    return string.format("%q", value)
  end
  if type(value) ~= "table" then
    return tostring(value)
  end
  if depth > 4 then
    return "{...}"
  end
  local keys = {}
  for k in pairs(value) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    if type(a) == "number" and type(b) == "number" then
      return a < b
    end
    return tostring(a) < tostring(b)
  end)
  local parts = {}
  local n = #value
  for _, k in ipairs(keys) do
    if type(k) == "number" and k >= 1 and k <= n and k % 1 == 0 then
      parts[#parts + 1] = inspect(value[k], depth + 1)
    else
      local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k
        or ("[" .. inspect(k) .. "]")
      parts[#parts + 1] = key .. " = " .. inspect(value[k], depth + 1)
    end
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

return inspect
