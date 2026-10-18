local define = require("lese.define")

---@class lese.builtin.previewer.FileDetail
---@field path string
---@field preview_path? string -- shown instead of `path` when set
---@field line? integer
---@field column? integer

---@class lese.builtin.previewer.FileOptions
---@field limit? integer -- lines read from the top, default 10000; more when detail.line is beyond

local BINARY = "No preview for binary file is available."

---Shows the file at `detail.preview_path` or `detail.path`.
---@param opts? lese.builtin.previewer.FileOptions
---@return lese.Previewer
return function(opts)
  opts = opts or {}
  local limit = opts.limit or 10000

  return define.previewer({
    name = "builtin.previewer.file",
    preview = function(ctx, params)
      local fn = ctx.host.fn
      local detail = params.item.detail
      local abspath = fn.fnamemodify(detail.preview_path or detail.path, ":p")
      if fn.filereadable(abspath) ~= 1 then
        return { content = { "Cannot read " .. abspath } }
      end
      local max = limit
      if detail.line and detail.line > max then
        max = detail.line + limit
      end
      local ok, content = pcall(fn.readfile, abspath, "", max)
      if not ok then
        return { content = { tostring(content) } }
      end
      -- readfile() turns a NUL byte into a line break inside the line.
      for i, line in ipairs(content) do
        if i % 1000 == 0 then
          ctx:checkpoint()
        end
        if line:find("\n", 1, true) then
          return { content = { BINARY } }
        end
      end
      return {
        content = content,
        filename = fn.fnamemodify(abspath, ":t"),
        line = detail.line,
        column = detail.column,
      }
    end,
  })
end
