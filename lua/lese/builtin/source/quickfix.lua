local define = require("lese.define")

---@class lese.builtin.source.QuickfixEntry
---@field bufnr integer     -- the buffer the entry refers to
---@field module string     -- the module name shown in place of the file name
---@field lnum integer      -- 1-based line number
---@field end_lnum? integer -- 1-based last line, when the entry spans lines
---@field col integer       -- 1-based column (a byte index unless vcol is 1)
---@field end_col? integer  -- 1-based column where the entry ends
---@field vcol integer      -- 1 when col is a screen column
---@field nr integer        -- the error number
---@field pattern string    -- the search pattern that locates the error
---@field text string       -- the description of the entry
---@field type string       -- the error type ("E", "W", …), empty when unset
---@field valid integer     -- 1 when the entry was recognized as an error message

---@class lese.builtin.source.QuickfixDetail
---@field bufnr integer                              -- the buffer the entry refers to
---@field line integer                               -- 1-based line number
---@field column integer                             -- 1-based column
---@field quickfix lese.builtin.source.QuickfixEntry -- the entry as `getqflist()` returned it

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
