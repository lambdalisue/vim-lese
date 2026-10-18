-- Path arithmetic for the built-in renderers, on strings only. Both / and \
-- separate components, so a Windows path works too.

local M = {}

---@param path string
---@return boolean
function M.is_absolute(path)
  return string.find(path, "^[/\\]") ~= nil or string.find(path, "^%a:[/\\]") ~= nil
end

---The separator `path` uses: \ when it has no /, else /.
---@param path string
---@return string
function M.separator(path)
  if string.find(path, "\\", 1, true) and not string.find(path, "/", 1, true) then
    return "\\"
  end
  return "/"
end

---@param path string
---@return string[]
local function components(path)
  local parts = {}
  for part in string.gmatch(path, "[^/\\]+") do
    if part ~= "." then
      parts[#parts + 1] = part
    end
  end
  return parts
end

---@param base string
---@param path string
---@return string
function M.join(base, path)
  local sep = M.separator(base)
  return (string.gsub(base, "[/\\]+$", "")) .. sep .. path
end

---`path` relative to `base`; both absolute.
---@param base string
---@param path string
---@return string
function M.relative(base, path)
  local from, to = components(base), components(path)
  local common = 0
  while common < #from and common < #to and from[common + 1] == to[common + 1] do
    common = common + 1
  end
  local parts = {}
  for _ = common + 1, #from do
    parts[#parts + 1] = ".."
  end
  for i = common + 1, #to do
    parts[#parts + 1] = to[i]
  end
  if #parts == 0 then
    return "."
  end
  return table.concat(parts, M.separator(path))
end

return M
