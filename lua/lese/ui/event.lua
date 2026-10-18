-- Events from <Plug> mappings reach the picker that is open on top. A picker
-- opened from an action (the action list, a submatch) stacks over the one
-- below it.

local host = require("lese.host")

local M = {}

---@class lese.EventHandler
---@field handle fun(self: lese.EventHandler, event: table)

---@type lese.EventHandler[]
local stack = {}

---@param handler lese.EventHandler
function M.push(handler)
  stack[#stack + 1] = handler
end

---@param handler lese.EventHandler
function M.pop(handler)
  for i = #stack, 1, -1 do
    if stack[i] == handler then
      table.remove(stack, i)
      return
    end
  end
end

---Called by lese#internal#dispatch().
---@param event table
function M.dispatch(event)
  local handler = stack[#stack]
  if handler then
    handler:handle(host.import(event))
  end
end

return M
