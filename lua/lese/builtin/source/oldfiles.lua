local define = require("lese.define")

---@class lese.builtin.source.OldfilesDetail
---@field path string

---Emits `v:oldfiles`, most recent first.
---@return lese.Source
return function()
  return define.source({
    name = "builtin.source.oldfiles",
    collect = function(ctx)
      local items = {}
      for i, p in ipairs(ctx.host.eval("v:oldfiles")) do
        items[i] = { id = i, value = p, detail = { path = p } }
      end
      ctx:emit(items)
    end,
  })
end
