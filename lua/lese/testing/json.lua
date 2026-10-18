-- A small JSON encoder for lese-run --json: objects get sorted keys so the
-- output is the same on every host.

local M = {}

local ESCAPES = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function encode_string(s)
  return '"'
    -- %c follows the C locale, which Vim may set so that UTF-8 continuation
    -- bytes count as control characters; name the ASCII ones instead.
    .. s:gsub('[%z\1-\31"\\]', function(c)
      return ESCAPES[c] or string.format("\\u%04x", string.byte(c))
    end)
    .. '"'
end

local function is_array(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n == #t
end

---@param value any
---@return string
function M.encode(value)
  local kind = type(value)
  if value == nil then
    return "null"
  elseif kind == "boolean" then
    return value and "true" or "false"
  elseif kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      return "null"
    end
    if value % 1 == 0 and math.abs(value) < 2 ^ 53 then
      return string.format("%d", value)
    end
    return string.format("%.14g", value)
  elseif kind == "string" then
    return encode_string(value)
  elseif kind == "table" then
    if next(value) == nil then
      return "[]"
    end
    if is_array(value) then
      local parts = {}
      for i, v in ipairs(value) do
        parts[i] = M.encode(v)
      end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(value) do
      keys[#keys + 1] = tostring(k)
    end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      local v = value[k]
      if v == nil then
        v = value[tonumber(k)]
      end
      parts[#parts + 1] = encode_string(k) .. ":" .. M.encode(v)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return encode_string(tostring(value))
end

return M
