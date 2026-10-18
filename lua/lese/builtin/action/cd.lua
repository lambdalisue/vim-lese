local build = require("lese.builtin.action._cmd")

---@class lese.builtin.action.CdOptions
---@field command? "cd"|"lcd"|"tcd" -- default "cd"

local function attr_getter(item)
  return item.detail.path or item.detail.bufname
end

---Changes the current directory to `detail.path` or `detail.bufname`, or to
---its parent when it is a file.
---@param opts? lese.builtin.action.CdOptions
---@return lese.Action
return function(opts)
  local command = (opts or {}).command or "cd"
  return build("builtin.action.cd", {
    attr_getter = attr_getter,
    immediate = true,
    template = command .. " {}",
    restriction = "directory-or-parent",
    fnameescape = true,
  })
end
