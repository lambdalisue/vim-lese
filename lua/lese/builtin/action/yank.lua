local define = require("lese.define")

---Puts the values of the chosen items (the selected items, or the item under
---the cursor), one per line, in `v:register`.
---@return lese.Action
return function()
  return define.action({
    name = "builtin.action.yank",
    invoke = function(ctx, params)
      local values = {}
      for i, item in ipairs(params.selected_items or { params.item }) do
        values[i] = item.value
      end
      ctx.host.fn.setreg(ctx.host.eval("v:register"), table.concat(values, "\n"))
    end,
  })
end
