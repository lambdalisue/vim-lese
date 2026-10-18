local define = require("lese.define")

---Emits nothing; a placeholder where a source is required.
---@return lese.Source
return function()
  return define.source({
    name = "builtin.source.noop",
    collect = function() end,
  })
end
