local define = require("lese.define")
local path = require("lese.builtin._path")

---@class lese.builtin.source.FileDetail
---@field path string -- absolute path of the file

---@class lese.builtin.source.FileOptions
---@field filter_file? fun(path: string): boolean       -- false leaves the file out
---@field filter_directory? fun(path: string): boolean  -- false skips the directory
---@field relative_from_base? boolean                   -- value is relative to the base directory

local function accept()
  return true
end

---Emits every file under the directory in `args[1]` (default: the current
---directory), walking it without external commands.
---@param opts? lese.builtin.source.FileOptions
---@return lese.Source
return function(opts)
  opts = opts or {}
  local filter_file = opts.filter_file or accept
  local filter_directory = opts.filter_directory or accept
  local relative_from_base = opts.relative_from_base or false

  return define.source({
    name = "builtin.source.file",
    collect = function(ctx, params)
      local fn = ctx.host.fn
      local sep = path.separator(ctx.host)
      local base = path.strip_trailing(fn.fnamemodify(fn.expand(params.args[1] or "."), ":p"))
      local offset = #path.join(base, "", sep) + 1
      local id = 0
      -- Directories already walked, by resolved path, so a symbolic link back
      -- to an ancestor does not loop.
      local visited = { [fn.resolve(base)] = true }

      local function walk(dir, real)
        local entries = ctx.host.readdir(dir)
        if not entries then
          return
        end
        local items = {}
        local subdirs = {}
        for i, entry in ipairs(entries) do
          if i % 256 == 0 then
            ctx:checkpoint()
          end
          local name, kind = entry.name, entry.kind
          local p = path.join(dir, name, sep)
          if kind == "file" then
            if filter_file(p) then
              id = id + 1
              items[#items + 1] = {
                id = id,
                value = relative_from_base and p:sub(offset) or p,
                detail = { path = p },
              }
            end
          else
            local r = kind == "link" and fn.resolve(p) or path.join(real, name, sep)
            if not visited[r] and filter_directory(p) then
              visited[r] = true
              subdirs[#subdirs + 1] = { p, r }
            end
          end
        end
        ctx:emit(items)
        ctx:checkpoint()
        for _, sub in ipairs(subdirs) do
          walk(sub[1], sub[2])
        end
      end

      if fn.isdirectory(base) == 1 then
        walk(base, fn.resolve(base))
      end
    end,
  })
end
