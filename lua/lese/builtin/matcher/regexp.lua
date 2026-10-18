local define = require("lese.define")

-- A pcall around the host call is not enough: Vim still reports the error,
-- and `vim -es` then exits with a failure. A :try keeps it quiet; it goes
-- through execute() with a list because a one-line `try | ... | endtry` does
-- not catch a pattern error, and Vim's Lua runs only one line per command.
---@param host lese.Host
---@param pattern string
---@return boolean
local function is_valid(host, pattern)
  local quoted = "'" .. string.gsub(pattern, "'", "''") .. "'"
  local output = host.fn.execute({
    "try",
    "call matchstrpos('', " .. quoted .. ")",
    "catch",
    "echon 'invalid'",
    "endtry",
  }, "silent")
  return output ~= "invalid"
end

---Keep the items that a Vim regular expression matches and decorate every
---match. The query is a Vim pattern, as for `match()`: 'magic' applies, and
---'ignorecase' decides the case unless the pattern has `\c` or `\C`. A pattern
---Vim rejects (often one still being typed) lets nothing through.
---@return lese.Matcher
return function()
  return define.matcher({
    name = "builtin.matcher.regexp",
    match = function(ctx, params)
      local pattern = string.match(params.query, "^%s*(.-)%s*$")
      if pattern == "" then
        ctx:emit(params.items)
        return
      end
      local host = ctx.host
      if not is_valid(host, pattern) then
        return
      end
      local matchstrpos = host.fn.matchstrpos
      local found = {}
      for i, item in ipairs(params.items) do
        if i % 64 == 0 then
          ctx:checkpoint()
        end
        local value = item.value
        local decorations = nil
        local start = 0
        while start <= #value do
          local m = matchstrpos(value, pattern, start)
          local s, e = m[2], m[3]
          if s < 0 then
            break
          end
          decorations = decorations or {}
          if e > s then
            decorations[#decorations + 1] = { column = s + 1, length = e - s }
            start = e
          else
            -- Step over the whole character after an empty match.
            local b = string.byte(value, s + 1) or 0
            start = s + (b >= 240 and 4 or b >= 224 and 3 or b >= 192 and 2 or 1)
          end
        end
        if decorations then
          local copy = {}
          for k, v in pairs(item) do
            copy[k] = v
          end
          local merged = {}
          for j, d in ipairs(item.decorations or {}) do
            merged[j] = d
          end
          for _, d in ipairs(decorations) do
            merged[#merged + 1] = d
          end
          copy.decorations = merged
          found[#found + 1] = copy
        end
      end
      ctx:emit(found)
    end,
  })
end
