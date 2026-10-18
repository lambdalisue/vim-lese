local define = require("lese.define")

---@class lese.builtin.source.QuickfixEntry
---@field bufnr integer
---@field module string
---@field lnum integer
---@field end_lnum? integer
---@field col integer
---@field end_col? integer
---@field vcol integer
---@field nr integer
---@field pattern string
---@field text string
---@field type string
---@field valid integer

---@class lese.builtin.source.QuickfixDetail
---@field bufnr integer
---@field line integer
---@field column integer
---@field quickfix lese.builtin.source.QuickfixEntry

---Emits the entries of the current quickfix list.
---@return lese.Source
return function()
  return define.source({
    name = "builtin.source.quickfix",
    collect = function(ctx)
      local items = {}
      for i, entry in ipairs(ctx.host.fn.getqflist()) do
        ctx:checkpoint()
        -- user_data may hold any Vim value; it is not part of the detail.
        entry.user_data = nil
        items[i] = {
          id = i,
          value = entry.text,
          detail = {
            bufnr = entry.bufnr,
            line = entry.lnum,
            column = entry.col,
            quickfix = entry,
          },
        }
      end
      ctx:emit(items)
    end,
  })
end
