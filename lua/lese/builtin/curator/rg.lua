local define = require("lese.define")
local path = require("lese.builtin._path")

---@class lese.builtin.curator.RgDetail
---@field path string    -- absolute path of the file
---@field line integer
---@field column integer
---@field context string -- the matched line

---@class lese.builtin.curator.RgOptions
---@field relative_from_base? boolean -- value shows the path relative to the base directory
---@field ignore_case? boolean        -- --ignore-case
---@field smart_case? boolean         -- --smart-case
---@field case_sensitive? boolean     -- --case-sensitive
---@field fixed_strings? boolean      -- --fixed-strings
---@field multiline? boolean          -- --multiline
---@field multiline_dotall? boolean   -- --multiline-dotall
---@field invert_match? boolean       -- --invert-match
---@field max_count? integer          -- --max-count
---@field pcre2? boolean              -- --pcre2
---@field type? string[]              -- --type, once for each
---@field type_not? string[]          -- --type-not, once for each
---@field glob? string[]              -- --glob, once for each
---@field hidden? boolean             -- --hidden
---@field follow? boolean             -- --follow
---@field max_depth? integer          -- --max-depth
---@field max_filesize? integer       -- --max-filesize, in bytes
---@field no_ignore? boolean          -- --no-ignore
---@field no_ignore_vcs? boolean      -- --no-ignore-vcs
---@field no_ignore_global? boolean   -- --no-ignore-global
---@field no_ignore_dot? boolean      -- --no-ignore-dot
---@field no_ignore_parent? boolean   -- --no-ignore-parent

local SWITCHES = {
  { "ignore_case", "--ignore-case" },
  { "smart_case", "--smart-case" },
  { "case_sensitive", "--case-sensitive" },
  { "fixed_strings", "--fixed-strings" },
  { "multiline", "--multiline" },
  { "multiline_dotall", "--multiline-dotall" },
  { "invert_match", "--invert-match" },
  { "max_count", "--max-count", "value" },
  { "pcre2", "--pcre2" },
  { "type", "--type", "list" },
  { "type_not", "--type-not", "list" },
  { "glob", "--glob", "list" },
  { "hidden", "--hidden" },
  { "follow", "--follow" },
  { "max_depth", "--max-depth", "value" },
  { "max_filesize", "--max-filesize", "value" },
  { "no_ignore", "--no-ignore" },
  { "no_ignore_vcs", "--no-ignore-vcs" },
  { "no_ignore_global", "--no-ignore-global" },
  { "no_ignore_dot", "--no-ignore-dot" },
  { "no_ignore_parent", "--no-ignore-parent" },
}

local function flags(opts)
  local args = {
    "--color=never",
    "--no-heading",
    "--no-messages",
    "--with-filename",
    "--line-number",
    "--column",
  }
  for _, switch in ipairs(SWITCHES) do
    local value = opts[switch[1]]
    if switch[3] == "list" then
      for _, v in ipairs(value or {}) do
        args[#args + 1] = switch[2]
        args[#args + 1] = v
      end
    elseif switch[3] == "value" then
      if value ~= nil then
        args[#args + 1] = switch[2]
        args[#args + 1] = tostring(value)
      end
    elseif value then
      args[#args + 1] = switch[2]
    end
  end
  return args
end

---Runs `rg` (ripgrep) on the directory in `args[1]` (default: the current
---directory) for each query.
---@param opts? lese.builtin.curator.RgOptions
---@return lese.Curator
return function(opts)
  opts = opts or {}
  local args = flags(opts)

  return define.curator({
    name = "builtin.curator.rg",
    curate = function(ctx, params)
      local fn = ctx.host.fn
      local sep = path.separator(ctx.host)
      local base = path.strip_trailing(fn.fnamemodify(fn.expand(params.args[1] or "."), ":p"))
      local cmd = { "rg" }
      for _, arg in ipairs(args) do
        cmd[#cmd + 1] = arg
      end
      -- -e keeps a query that starts with - from reading as an option.
      cmd[#cmd + 1] = "-e"
      cmd[#cmd + 1] = params.query
      cmd[#cmd + 1] = "--"
      cmd[#cmd + 1] = base
      ctx:spawn(cmd, {
        on_stdout = function(record)
          local p, line, column, context = record:match("^(.-):(%d+):(%d+):(.*)$")
          if not p then
            return
          end
          local vpath = opts.relative_from_base and path.relative(base, p, sep) or p
          ctx:emit({
            id = p .. ":" .. line .. ":" .. column,
            value = vpath .. ":" .. line .. ":" .. column .. ":" .. context,
            detail = {
              path = p,
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
