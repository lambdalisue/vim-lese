local define = require("lese.define")
local path = require("lese.builtin._textpath")
local label = require("lese.builtin._label")

---@class lese.builtin.renderer.RelativePathOptions
---@field base? string -- default: the current directory

---Rewrite the absolute `item.detail.path` in the label as a path relative to
---the base.
---@param opts? lese.builtin.renderer.RelativePathOptions
---@return lese.Renderer
return function(opts)
  opts = opts or {}
  return define.renderer({
    name = "builtin.renderer.relative_path",
    render = function(ctx, params)
      local base = opts.base or ctx.host.fn.getcwd()
      for i, item in ipairs(params.items) do
        if i % 256 == 0 then
          ctx:checkpoint()
        end
        local p = item.detail.path
        if type(p) == "string" and path.is_absolute(p) then
          local s = string.find(item.label, p, 1, true)
          if s then
            label.replace(item, s, #p, path.relative(base, p))
          end
        end
      end
    end,
  })
end
