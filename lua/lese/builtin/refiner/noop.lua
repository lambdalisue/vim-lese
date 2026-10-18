local define = require("lese.define")

---Passes every item through unchanged.
---@return lese.Refiner
return function()
  return define.refiner({
    name = "builtin.refiner.noop",
    refine = function(_, item)
      return item
    end,
  })
end
