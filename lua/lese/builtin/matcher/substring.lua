local define = require("lese.define")

local find, gsub, char = string.find, string.gsub, string.char

-- string.lower follows the C locale and may fold bytes of UTF-8 characters.
local ASCII_LOWER = {}
for b = 65, 90 do
  ASCII_LOWER[char(b)] = char(b + 32)
end

local function fold(s)
  return (gsub(s, "[A-Z]", ASCII_LOWER))
end

---@class lese.builtin.matcher.SubstringOptions
---@field smart_case? boolean  -- ignore case while the query has no upper-case letter
---@field ignore_case? boolean -- always ignore case; wins over smart_case

---Keep the items that contain every whitespace-separated term of the query,
---taken literally, and decorate each occurrence. Case is respected unless an
---option says otherwise.
---@param opts? lese.builtin.matcher.SubstringOptions
---@return lese.Matcher
return function(opts)
  opts = opts or {}
  return define.matcher({
    name = "builtin.matcher.substring",
    -- More text in a term, or another term, can only keep fewer items.
    narrows = function(previous, query)
      return query:sub(1, #previous) == previous
    end,
    match = function(ctx, params)
      local query = params.query
      local ignore_case = opts.ignore_case or (opts.smart_case and not find(query, "[A-Z]"))
      local terms = {}
      for term in string.gmatch(query, "%S+") do
        terms[#terms + 1] = ignore_case and fold(term) or term
      end
      if #terms == 0 then
        ctx:emit(params.items)
        return
      end
      local found = {}
      for i, item in ipairs(params.items) do
        if i % 256 == 0 then
          ctx:checkpoint()
        end
        local value = ignore_case and fold(item.value) or item.value
        local all = true
        for _, term in ipairs(terms) do
          if not find(value, term, 1, true) then
            all = false
            break
          end
        end
        if all then
          local decorations = {}
          for j, d in ipairs(item.decorations or {}) do
            decorations[j] = d
          end
          local pos = 1
          while true do
            local best_s, best_e
            for _, term in ipairs(terms) do
              local s, e = find(value, term, pos, true)
              if s and (not best_s or s < best_s) then
                best_s, best_e = s, e
              end
            end
            if not best_s then
              break
            end
            decorations[#decorations + 1] = { column = best_s, length = best_e - best_s + 1 }
            pos = best_e + 1
          end
          local copy = {}
          for k, v in pairs(item) do
            copy[k] = v
          end
          copy.decorations = decorations
          found[#found + 1] = copy
        end
      end
      ctx:emit(found)
    end,
  })
end
