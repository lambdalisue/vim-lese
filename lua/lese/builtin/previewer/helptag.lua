local define = require("lese.define")

---@class lese.builtin.previewer.HelptagDetail
---@field helptag string  -- the tag to jump to
---@field helpfile string -- the file name under doc/
---@field lang? string    -- the language of a translated help file (ja for tags-ja)

-- The path of each help file, keyed by 'runtimepath' and file name.
local cache = {}

---Shows the help file that defines `detail.helptag`, at the tag.
---@return lese.Previewer
return function()
  return define.previewer({
    name = "builtin.previewer.helptag",
    preview = function(ctx, params)
      local fn = ctx.host.fn
      local detail = params.item.detail
      local runtimepath = ctx.host.eval("&runtimepath")
      local key = runtimepath .. "\n" .. detail.helpfile
      local file = cache[key]
      if not file then
        file = fn.globpath(runtimepath, "doc/" .. detail.helpfile, 1, 1)[1]
        if not file then
          return nil
        end
        cache[key] = file
      end
      local ok, content = pcall(fn.readfile, file)
      if not ok then
        return nil
      end
      local needle = "*" .. detail.helptag .. "*"
      local line
      for i, text in ipairs(content) do
        if i % 1000 == 0 then
          ctx:checkpoint()
        end
        if text:find(needle, 1, true) then
          line = i
          break
        end
      end
      return { content = content, filetype = "help", line = line }
    end,
  })
end
