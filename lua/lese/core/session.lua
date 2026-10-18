-- Pickers closed in this editor session, newest last, to resume them.

local M = {}

M.MAX_COUNT = 100

---@class lese.PickerSession
---@field name string
---@field args string[]
---@field context lese.PickerContext

---@type lese.PickerSession[]
local sessions = {}

---@param session lese.PickerSession
function M.save(session)
  sessions[#sessions + 1] = session
  if #sessions > M.MAX_COUNT then
    table.remove(sessions, 1)
  end
end

---Every session, newest first.
---@return lese.PickerSession[]
function M.list()
  local out = {}
  for i = #sessions, 1, -1 do
    out[#out + 1] = sessions[i]
  end
  return out
end

---The `number`-th newest session, among those of picker `name` when given.
---@param name? string
---@param number? integer  -- 1 is the newest
---@return lese.PickerSession?
function M.load(name, number)
  local n = 0
  for i = #sessions, 1, -1 do
    local session = sessions[i]
    if not name or name == "" or session.name == name then
      n = n + 1
      if n == (number or 1) then
        return session
      end
    end
  end
  return nil
end

function M.clear()
  sessions = {}
end

return M
