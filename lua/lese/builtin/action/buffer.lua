local build = require("lese.builtin.action._cmd")

---@alias lese.builtin.action.BufferCommand "bunload"|"bdelete"|"bwipeout"|"write"

---@class lese.builtin.action.BufferOptions
---@field command? lese.builtin.action.BufferCommand -- default "bdelete"

local TEMPLATES = {
  bunload = "bunload {}",
  bdelete = "bdelete {}",
  bwipeout = "bwipeout {}",
  write = "tabedit {} | write | tabclose",
}

local function attr_getter(item)
  return item.detail.path or item.detail.bufname
end

---Runs a buffer command on the loaded buffer of `detail.path` or
---`detail.bufname`.
---@param opts? lese.builtin.action.BufferOptions
---@return lese.Action
return function(opts)
  local command = (opts or {}).command or "bdelete"
  local template = TEMPLATES[command]
  if not template then
    error(string.format("builtin.action.buffer: unknown command '%s'", tostring(command)), 2)
  end
  return build("builtin.action.buffer", {
    attr_getter = attr_getter,
    immediate = true,
    template = template,
    restriction = "buffer",
    fnameescape = true,
  })
end
