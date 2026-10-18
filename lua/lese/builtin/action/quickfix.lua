local define = require("lese.define")

---@class lese.builtin.action.QuickfixDetail
---@field path? string
---@field bufname? string
---@field bufnr? integer
---@field line? integer
---@field column? integer
---@field length? integer  -- bytes from column; sets end_col
---@field context? string  -- the entry's text

---@class lese.builtin.action.QuickfixOptions
---@field what? table             -- merged into setqflist()'s {what} (title, id, nr, ...)
---@field action? "a"|"r"|"f"|" " -- setqflist()'s {action}, default " "
---@field after? string           -- an Ex command to run afterwards, e.g. "copen"
---@field continue? boolean       -- keep the picker open

local function entry(detail)
  local e = {
    filename = detail.bufname or detail.path,
    lnum = detail.line,
    col = detail.column,
    text = detail.context or "",
  }
  if e.filename == nil or e.filename == "" then
    e.filename = nil
    e.bufnr = detail.bufnr
  end
  if detail.column and detail.length then
    e.end_col = detail.column + detail.length
  end
  return e
end

---Puts the chosen items (the selected items, or every filtered item) in the
---quickfix list.
---@param opts? lese.builtin.action.QuickfixOptions
---@return lese.Action
return function(opts)
  opts = opts or {}
  local action = opts.action or " "

  return define.action({
    name = "builtin.action.quickfix",
    invoke = function(ctx, params)
      local items = {}
      for i, item in ipairs(params.selected_items or params.filtered_items) do
        if i % 1000 == 0 then
          ctx:checkpoint()
        end
        items[i] = entry(item.detail)
      end
      local what = { items = items }
      for k, v in pairs(opts.what or {}) do
        what[k] = v
      end
      ctx.host.fn.setqflist({}, action, what)
      if opts.after and opts.after ~= "" then
        ctx.host.cmd(opts.after)
      end
      if opts.continue then
        return true
      end
      return nil
    end,
  })
end
