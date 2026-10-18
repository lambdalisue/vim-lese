local define = require("lese.define")

---Emits nothing; a placeholder where a curator is required.
---@return lese.Curator
return function()
  return define.curator({
    name = "builtin.curator.noop",
    curate = function() end,
  })
end
