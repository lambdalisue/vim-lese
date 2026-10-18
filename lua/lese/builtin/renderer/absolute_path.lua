local define = require("lese.define")
local path = require("lese.builtin._textpath")
local label = require("lese.builtin._label")

---@class lese.builtin.renderer.AbsolutePathOptions
---@field base? string -- default: the current directory

---Rewrite a relative `item.detail.path` in the label as an absolute path
---under the base.
---@param opts? lese.builtin.renderer.AbsolutePathOptions
---@return lese.Renderer
return function(opts)
  opts = opts or {}
  return define.renderer({
    name = "builtin.renderer.absolute_path",
    render = function(ctx, params)
      local base = opts.base or ctx.host.fn.getcwd()
      for i, item in ipairs(params.items) do
        if i % 256 == 0 then
          ctx:checkpoint()
        end
        local p = item.detail.path
        if type(p) == "string" and not path.is_absolute(p) then
          local s = string.find(item.label, p, 1, true)
          if s then
            label.replace(item, s, #p, path.join(base, p))
          end
        end
      end
    end,
  })
end
