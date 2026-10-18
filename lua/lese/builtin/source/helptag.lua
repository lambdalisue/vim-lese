local define = require("lese.define")

---@class lese.builtin.source.HelptagDetail
---@field helptag string
---@field helpfile string  -- the file name under doc/
---@field lang? string     -- the language of a translated tags file (tags-ja)

---Emits the help tags of every `doc/tags` and `doc/tags-xx` on 'runtimepath'.
---A tag is emitted once per language, from the first directory that has it.
---@return lese.Source
return function()
  return define.source({
    name = "builtin.source.helptag",
    collect = function(ctx)
      local fn = ctx.host.fn
      local seen = {}
      local id = 0
      local files = fn.globpath(ctx.host.eval("&runtimepath"), "doc/tags*", 1, 1)
      for _, file in ipairs(files) do
        local name = fn.fnamemodify(file, ":t")
        local lang = name:match("^tags%-([a-z][a-z])$")
        if name == "tags" or lang then
          local ok, lines = pcall(fn.readfile, file)
          if ok then
            local items = {}
            for i, line in ipairs(lines) do
              if i % 1000 == 0 then
                ctx:checkpoint()
              end
              local helptag, helpfile = line:match("^([^\t]+)\t([^\t]+)")
              if helptag and not helptag:find("^!_TAG_") then
                local key = helptag .. ":" .. (lang or "")
                if not seen[key] then
                  seen[key] = true
                  id = id + 1
                  items[#items + 1] = {
                    id = id,
                    value = helptag,
                    detail = { helptag = helptag, helpfile = helpfile, lang = lang },
                  }
                end
              end
            end
            ctx:emit(items)
          end
        end
        ctx:checkpoint()
      end
    end,
  })
end
