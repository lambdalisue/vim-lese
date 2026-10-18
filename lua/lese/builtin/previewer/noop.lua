local define = require("lese.define")

---Shows nothing; a placeholder where a previewer is required.
---@return lese.Previewer
return function()
  return define.previewer({
    name = "builtin.previewer.noop",
    preview = function()
      return nil
    end,
  })
end
