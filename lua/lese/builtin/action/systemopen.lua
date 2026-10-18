local define = require("lese.define")

---@class lese.builtin.action.SystemopenOptions
---@field command? string[] -- the opener, given the path as its last argument; default: open, explorer or xdg-open

local function default_command(fn)
  if fn.has("win32") == 1 then
    return { "explorer" }
  elseif fn.has("mac") == 1 or fn.has("macunix") == 1 then
    return { "open" }
  end
  return { "xdg-open" }
end

---Opens `detail.path` of each chosen item with the system's default
---application.
---@param opts? lese.builtin.action.SystemopenOptions
---@return lese.Action
return function(opts)
  opts = opts or {}

  return define.action({
    name = "builtin.action.systemopen",
    invoke = function(ctx, params)
      local base = opts.command or default_command(ctx.host.fn)
      for _, item in ipairs(params.selected_items or { params.item }) do
        local cmd = {}
        for i, arg in ipairs(base) do
          cmd[i] = arg
        end
        cmd[#cmd + 1] = item.detail.path
        ctx:spawn(cmd)
      end
    end,
  })
end
