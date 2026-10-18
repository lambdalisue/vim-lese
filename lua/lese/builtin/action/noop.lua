local define = require("lese.define")

---Does nothing; a placeholder where an action is required.
---@return lese.Action
return function()
  return define.action({
    name = "builtin.action.noop",
    invoke = function() end,
  })
end
