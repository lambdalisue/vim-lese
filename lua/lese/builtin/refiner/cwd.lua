local define = require("lese.define")
local path = require("lese.builtin._path")

---Keeps the items whose `detail.path` is under the current directory.
---@return lese.Refiner
return function()
  return define.refiner({
    name = "builtin.refiner.cwd",
    refine = function(ctx, item)
      local cwd = ctx.host.fn.getcwd()
      local p = item.detail.path
      local prefix = path.join(cwd, "", path.separator(ctx.host))
      if p == cwd or p:sub(1, #prefix) == prefix then
        return item
      end
      return nil
    end,
  })
end
