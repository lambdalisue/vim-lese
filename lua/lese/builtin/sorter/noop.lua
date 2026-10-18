local define = require("lese.define")

---A sorter that keeps the order.
---@return lese.Sorter
return function()
  return define.sorter({
    name = "builtin.sorter.noop",
    sort = function() end,
  })
end
