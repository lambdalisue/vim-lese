local define = require("lese.define")

---@alias lese.builtin.source.HistoryMode "cmd"|"search"|"expr"|"input"|"debug"

---@class lese.builtin.source.History
---@field line string                          -- the history entry's text
---@field mode lese.builtin.source.HistoryMode -- which history the entry comes from
---@field index integer                        -- the entry's index in the history
---@field histnr integer                       -- the index of the newest entry

---@class lese.builtin.source.HistoryDetail
---@field history lese.builtin.source.History -- the entry and where it sits in its history

---@class lese.builtin.source.HistoryOptions
---@field mode? lese.builtin.source.HistoryMode -- default "cmd"

---Emits the entries of a history, newest first.
---@param opts? lese.builtin.source.HistoryOptions
---@return lese.Source
return function(opts)
  opts = opts or {}
  local mode = opts.mode or "cmd"

  return define.source({
    name = "builtin.source.history",
    collect = function(ctx)
      local fn = ctx.host.fn
      local histnr = fn.histnr(mode)
      local id = 0
      for index = histnr, 1, -1 do
        ctx:checkpoint()
        local line = fn.histget(mode, index)
        if line ~= "" then
          id = id + 1
          ctx:emit({
            id = id,
            value = line,
            detail = {
              history = { line = line, mode = mode, index = index, histnr = histnr },
            },
          })
        end
      end
    end,
  })
end
