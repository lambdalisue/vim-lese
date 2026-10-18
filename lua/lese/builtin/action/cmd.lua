local build = require("lese.builtin.action._cmd")

---Runs an Ex command built from each chosen item (the selected items, or the
---item under the cursor).
---@param opts? lese.builtin.action.CmdOptions
---@return lese.Action
return function(opts)
  return build("builtin.action.cmd", opts)
end
