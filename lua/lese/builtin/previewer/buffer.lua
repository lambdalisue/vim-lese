local define = require("lese.define")

---@class lese.builtin.previewer.BufferDetail
---@field bufnr integer   -- the buffer to show
---@field line? integer   -- 1-based line to put the cursor on
---@field column? integer -- 1-based byte column

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
