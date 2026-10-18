local define = require("lese.define")

---Shows the chosen items (the selected items, or the item under the cursor)
---in the message history.
---@return lese.Action
return function()
  return define.action({
    name = "builtin.action.echo",
    invoke = function(ctx, params)
      ctx.host.echo(ctx.host.fn.string(params.selected_items or params.item))
    end,
  })
end
