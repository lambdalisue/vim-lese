local define = require("lese.define")

---@class lese.builtin.source.LineDetail
---@field bufnr integer
---@field bufname string
---@field line integer    -- 1-based line number
---@field context string  -- the line's text

---@class lese.builtin.source.LineOptions
---@field chunk_size? integer -- lines read at once, default 1000

---Emits each line of the buffer in `args[1]` (default: the current buffer).
---@param opts? lese.builtin.source.LineOptions
---@return lese.Source
return function(opts)
  opts = opts or {}
  local chunk_size = opts.chunk_size or 1000

  return define.source({
    name = "builtin.source.line",
    collect = function(ctx, params)
      local fn = ctx.host.fn
      local expr = params.args[1] or "%"
      local bufnr = fn.bufnr(tonumber(expr) or expr)
      if bufnr < 1 then
        return
      end
      fn.bufload(bufnr)
      local bufname = fn.bufname(bufnr)
      local count = fn.getbufinfo(bufnr)[1].linecount
      local width = #tostring(count)
      local format = "%" .. width .. "d %s"
      local lnum = 1
      while lnum <= count do
        local lines = fn.getbufline(bufnr, lnum, lnum + chunk_size - 1)
        local items = {}
        for i, text in ipairs(lines) do
          local line = lnum + i - 1
          items[i] = {
            id = line,
            value = string.format(format, line, text),
            detail = { bufnr = bufnr, bufname = bufname, line = line, context = text },
          }
        end
        ctx:emit(items)
        ctx:checkpoint()
        lnum = lnum + chunk_size
      end
    end,
  })
end
