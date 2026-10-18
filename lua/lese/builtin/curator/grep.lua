local define = require("lese.define")
local path = require("lese.builtin._path")

---@class lese.builtin.curator.GrepDetail
---@field path string    -- absolute path of the file
---@field line integer   -- 1-based line number of the match
---@field context string -- the matched line

---@class lese.builtin.curator.GrepOptions
---@field relative_from_base? boolean -- value shows the path relative to the base directory

---Runs `grep -r` on the directory in `args[1]` (default: the current directory)
---for each query.
---@param opts? lese.builtin.curator.GrepOptions
---@return lese.Curator
return function(opts)
  opts = opts or {}

  return define.curator({
    name = "builtin.curator.grep",
    curate = function(ctx, params)
      local fn = ctx.host.fn
      local sep = path.separator(ctx.host)
      local base = path.strip_trailing(fn.fnamemodify(fn.expand(params.args[1] or "."), ":p"))
      local cmd = {
        "grep",
        "--color=never",
        "--no-messages",
        "--recursive",
        "--line-number",
        -- -e keeps a query that starts with - from reading as an option.
        "-e",
        params.query,
        "--",
        base,
      }
      ctx:spawn(cmd, {
        on_stdout = function(record)
          local p, line, context = record:match("^(.-):(%d+):(.*)$")
          if not p then
            return
          end
          local vpath = opts.relative_from_base and path.relative(base, p, sep) or p
          ctx:emit({
            id = p .. ":" .. line,
            value = vpath .. ":" .. line .. ":" .. context,
            detail = { path = p, line = tonumber(line), context = context },
          })
        end,
      })
    end,
  })
end
