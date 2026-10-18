-- Path helpers the built-in modules share. Pure Lua: paths are plain strings
-- and the separator is passed in, so Windows paths work on any host.

local M = {}

---The separator the host uses in the paths it returns.
---@param host lese.Host
---@return string
function M.separator(host)
  if host.fn.has("win32") == 1 then
    return "\\"
  end
  return "/"
end

---@param path string
---@return boolean
function M.is_absolute(path)
  return path:find("^[/\\]") ~= nil or path:find("^[A-Za-z]:[/\\]") ~= nil
end

local function is_root(path)
  return path:find("^[/\\]$") ~= nil or path:find("^[A-Za-z]:[/\\]$") ~= nil
end

---Remove one trailing separator, unless the path is a root.
---@param path string
---@return string
function M.strip_trailing(path)
  if is_root(path) then
    return path
  end
  return (path:gsub("[/\\]$", ""))
end

---@param base string
---@param name string
---@param sep string
---@return string
function M.join(base, name, sep)
  if base:find("[/\\]$") then
    return base .. name
  end
  return base .. sep .. name
end

local function split(path)
  local parts = {}
  for part in path:gmatch("[^/\\]+") do
    if part ~= "." then
      parts[#parts + 1] = part
    end
  end
  return parts
end

---`path` relative to `base`, both absolute. A relative `path` is returned as is.
---@param base string
---@param path string
---@param sep string
---@return string
function M.relative(base, path, sep)
  if not M.is_absolute(path) then
    return path
  end
  local from, to = split(base), split(path)
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
  return table.concat(parts, sep)
end

---Replace the first occurrence of `old` in `text` with `new`, literally.
---@param text string
---@param old string
---@param new string
---@return string
function M.replace(text, old, new)
  local s, e = text:find(old, 1, true)
  if not s then
    return text
  end
  return text:sub(1, s - 1) .. new .. text:sub(e + 1)
end

return M
