-- Split a command line into arguments the way :Lese reads them.

local M = {}

---Split on spaces, honouring single and double quotes and backslash escapes.
---An unclosed quote runs to the end; a trailing backslash is dropped.
---@param cmdline string
---@return string[]
function M.parse(cmdline)
  local args = {}
  local current = {}
  local quote = nil
  local escaped = false
  local function push()
    if #current > 0 then
      args[#args + 1] = table.concat(current)
      current = {}
    end
  end
  for i = 1, #cmdline do
    local c = cmdline:sub(i, i)
    if escaped then
      current[#current + 1] = c
      escaped = false
    elseif c == "\\" then
      escaped = true
    elseif c == '"' or c == "'" then
      if quote == c then
        quote = nil
      elseif quote == nil then
        quote = c
      else
        current[#current + 1] = c
      end
    elseif c == " " and quote == nil then
      push()
    else
      current[#current + 1] = c
    end
  end
  push()
  return args
end

return M
