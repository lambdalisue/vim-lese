local define = require("lese.define")

---A renderer that leaves the label as it is.
---@return lese.Renderer
return function()
  return define.renderer({
    name = "builtin.renderer.noop",
    render = function() end,
  })
end
