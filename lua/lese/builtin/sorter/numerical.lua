local define = require("lese.define")

---@class lese.builtin.sorter.NumericalOptions
---@field key? fun(item: lese.Item): (number|string|nil) -- what to compare (default: the value)
---@field reverse? boolean

---Order items by a number: the key itself, or the string it converts from.
---Items whose key is not a number go after the others. Items with equal keys
---keep their order.
---@param opts? lese.builtin.sorter.NumericalOptions
---@return lese.Sorter
return function(opts)
  opts = opts or {}
  local key = opts.key or function(item)
    return item.value
  end
  local reverse = opts.reverse == true
  return define.sorter({
    name = "builtin.sorter.numerical",
    sort = function(ctx, params)
      local items = params.items
      local entries = {}
      for i, item in ipairs(items) do
        if i % 1024 == 0 then
          ctx:checkpoint()
        end
        local n = tonumber(key(item))
        if n ~= n then
          n = nil
        end
        entries[i] = { key = n, index = i, item = item }
      end
      table.sort(entries, function(a, b)
        local ka, kb = a.key, b.key
        if ka ~= kb then
          if ka == nil then
            return false
          elseif kb == nil then
            return true
          elseif reverse then
            return ka > kb
          end
          return ka < kb
        end
        return a.index < b.index
      end)
      for i, entry in ipairs(entries) do
        items[i] = entry.item
      end
    end,
  })
end
