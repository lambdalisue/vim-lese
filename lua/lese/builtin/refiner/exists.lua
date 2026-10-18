local define = require("lese.define")

---Keeps the items whose `detail.path` is a file or directory that exists.
---@return lese.Refiner
return function()
  return define.refiner({
    name = "builtin.refiner.exists",
    refine = function(ctx, item)
      local fn = ctx.host.fn
      local p = item.detail.path
      if fn.filereadable(p) == 1 or fn.isdirectory(p) == 1 then
        return item
      end
      return nil
    end,
  })
end
