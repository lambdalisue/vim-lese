local define = require("lese.define")

---Emits a fixed list of items.
---@param items lese.Item[]
---@return lese.Source
return function(items)
  return define.source({
    name = "builtin.source.list",
    collect = function(ctx)
      ctx:emit(items)
    end,
  })
end
