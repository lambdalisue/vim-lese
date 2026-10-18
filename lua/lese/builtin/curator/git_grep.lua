local define = require("lese.define")
local path = require("lese.builtin._path")

---@class lese.builtin.curator.GitGrepDetail
---@field path string    -- absolute path of the file
---@field line integer   -- 1-based line number of the match
---@field column integer -- 1-based byte column of the match
---@field context string -- the matched line

---Runs `git grep` in the current directory for each query.
---@return lese.Curator
return function()
  return define.curator({
    name = "builtin.curator.git_grep",
    curate = function(ctx, params)
      local sep = path.separator(ctx.host)
      local cwd = ctx.host.fn.getcwd()
      -- Without --full-name git prints paths relative to the current
      -- directory, which is what they are joined to.
      local cmd = {
        "git",
        "grep",
        "--color=never",
        "--no-heading",
        "--line-number",
        "--column",
        -- -e keeps a query that starts with - from reading as an option.
        "-e",
        params.query,
      }
      ctx:spawn(cmd, {
        cwd = cwd,
        on_stdout = function(record)
          local p, line, column, context = record:match("^(.-):(%d+):(%d+):(.*)$")
          if not p then
            return
          end
          if sep == "\\" then
            p = p:gsub("/", "\\")
          end
          local abspath = path.join(cwd, p, sep)
          local position = abspath .. ":" .. line .. ":" .. column
          ctx:emit({
            id = position,
            value = position .. ":" .. context,
            detail = {
              path = abspath,
              line = tonumber(line),
              column = tonumber(column),
              context = context,
            },
          })
        end,
      })
    end,
  })
end
