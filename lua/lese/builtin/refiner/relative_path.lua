local define = require("lese.define")
local path = require("lese.builtin._path")

---@class lese.builtin.refiner.RelativePathDetail
---@field path string    -- the path to make relative; it appears in the value
---@field relpath string -- set by this refiner

---@class lese.builtin.refiner.RelativePathOptions
---@field base? string -- what paths are made relative to, default: the current directory

---Replaces `detail.path` in the value with its path relative to the base, and
---keeps that in `detail.relpath`.
---@param opts? lese.builtin.refiner.RelativePathOptions
---@return lese.Refiner
return function(opts)
  opts = opts or {}

  return define.refiner({
    name = "builtin.refiner.relative_path",
    refine = function(ctx, item)
      local p = item.detail.path
      local base = opts.base or ctx.host.fn.getcwd()
      local relpath = path.relative(base, p, path.separator(ctx.host))
      local detail = {}
      for k, v in pairs(item.detail) do
        detail[k] = v
      end
      detail.relpath = relpath
      local refined = {}
      for k, v in pairs(item) do
        refined[k] = v
      end
      refined.value = path.replace(item.value, p, relpath)
      refined.detail = detail
      return refined
    end,
  })
end
