local define = require("lese.define")
local path = require("lese.builtin._path")

---@class lese.builtin.refiner.AbsolutePathDetail
---@field path string    -- the path to make absolute; it appears in the value
---@field abspath string -- set by this refiner

---@class lese.builtin.refiner.AbsolutePathOptions
---@field base? string -- what relative paths are joined to, default: the current directory

---Replaces `detail.path` in the value with its absolute path, and keeps that
---in `detail.abspath`.
---@param opts? lese.builtin.refiner.AbsolutePathOptions
---@return lese.Refiner
return function(opts)
  opts = opts or {}

  return define.refiner({
    name = "builtin.refiner.absolute_path",
    refine = function(ctx, item)
      local p = item.detail.path
      local abspath = p
      if not path.is_absolute(p) then
        abspath = path.join(opts.base or ctx.host.fn.getcwd(), p, path.separator(ctx.host))
      end
      local detail = {}
      for k, v in pairs(item.detail) do
        detail[k] = v
      end
      detail.abspath = abspath
      local refined = {}
      for k, v in pairs(item) do
        refined[k] = v
      end
      refined.value = path.replace(item.value, p, abspath)
      refined.detail = detail
      return refined
    end,
  })
end
