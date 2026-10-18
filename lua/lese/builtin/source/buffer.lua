local define = require("lese.define")

---The buffer's entry of `getbufinfo()`.
---@class lese.builtin.source.BufferInfo
---@field bufnr integer    -- the buffer number
---@field name string      -- the full path of the buffer's file
---@field listed integer   -- 1 when the buffer is listed
---@field loaded integer   -- 1 when the buffer is loaded
---@field changed integer  -- 1 when the buffer is modified
---@field hidden integer   -- 1 when the buffer is loaded but not in a window
---@field lnum integer     -- 1-based cursor line when the buffer was last in the current window
---@field lastused integer -- seconds since the epoch when the buffer was last used

---@class lese.builtin.source.BufferDetail
---@field bufnr integer    -- the buffer number
---@field bufname string   -- the full name of the buffer (`getbufinfo().name`)
---@field bufinfo lese.builtin.source.BufferInfo -- what `getbufinfo()` reported

---@alias lese.builtin.source.BufferFilter "buflisted"|"bufloaded"|"bufmodified"

---@class lese.builtin.source.BufferOptions
---@field filter? lese.builtin.source.BufferFilter -- default: every named buffer

local FIELDS = {
  buflisted = "listed",
  bufloaded = "loaded",
  bufmodified = "changed",
}

---Emits the named buffers.
---@param opts? lese.builtin.source.BufferOptions
---@return lese.Source
return function(opts)
  opts = opts or {}
  local field = opts.filter and FIELDS[opts.filter]
  if opts.filter and not field then
    error(string.format("builtin.source.buffer: unknown filter '%s'", tostring(opts.filter)), 2)
  end

  return define.source({
    name = "builtin.source.buffer",
    collect = function(ctx)
      local items = {}
      for _, info in ipairs(ctx.host.fn.getbufinfo()) do
        ctx:checkpoint()
        if info.name ~= "" and (not field or info[field] == 1) then
          items[#items + 1] = {
            id = info.bufnr,
            value = info.name,
            detail = {
              bufnr = info.bufnr,
              bufname = info.name,
              bufinfo = {
                bufnr = info.bufnr,
                name = info.name,
                listed = info.listed,
                loaded = info.loaded,
                changed = info.changed,
                hidden = info.hidden,
                lnum = info.lnum,
                lastused = info.lastused,
              },
            },
          }
        end
      end
      ctx:emit(items)
    end,
  })
end
