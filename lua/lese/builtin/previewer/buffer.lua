local define = require("lese.define")

---@class lese.builtin.previewer.BufferDetail
---@field bufnr integer
---@field line? integer
---@field column? integer

---Shows the buffer at `detail.bufnr`, loading it when needed.
---@return lese.Previewer
return function()
  return define.previewer({
    name = "builtin.previewer.buffer",
    preview = function(ctx, params)
      local fn = ctx.host.fn
      local detail = params.item.detail
      local bufnr = detail.bufnr
      if fn.bufexists(bufnr) ~= 1 then
        return nil
      end
      fn.bufload(bufnr)
      return {
        content = fn.getbufline(bufnr, 1, "$"),
        filename = fn.fnamemodify(fn.bufname(bufnr), ":t"),
        filetype = fn.getbufvar(bufnr, "&filetype"),
        line = detail.line,
        column = detail.column,
      }
    end,
  })
end
