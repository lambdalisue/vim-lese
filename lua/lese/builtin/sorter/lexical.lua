local define = require("lese.define")

---@class lese.builtin.sorter.LexicalOptions
---@field key? fun(item: lese.Item): string -- what to compare (default: the value)
---@field reverse? boolean

---Order items by comparing strings byte by byte. Items with equal keys keep
---their order.
---@param opts? lese.builtin.sorter.LexicalOptions
---@return lese.Sorter
return function(opts)
  opts = opts or {}
  local key = opts.key or function(item)
    return item.value
  end
  local reverse = opts.reverse == true
  return define.sorter({
    name = "builtin.sorter.lexical",
    sort = function(ctx, params)
      local items = params.items
      local entries = {}
      for i, item in ipairs(items) do
        if i % 1024 == 0 then
          ctx:checkpoint()
        end
        entries[i] = { key = key(item), index = i, item = item }
      end
      table.sort(entries, function(a, b)
        if a.key ~= b.key then
          if reverse then
            return a.key > b.key
          end
          return a.key < b.key
        end
        return a.index < b.index
      end)
      for i, entry in ipairs(entries) do
        items[i] = entry.item
      end
    end,
  })
end
