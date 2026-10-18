local define = require("lese.define")

---@class lese.builtin.refiner.RegexpOptions
---@field includes? string[] -- keep a value that matches any of these
---@field excludes? string[] -- drop a value that matches any of these

local function matches_any(fn, value, patterns)
  for _, pattern in ipairs(patterns) do
    if fn.match(value, pattern) >= 0 then
      return true
    end
  end
  return false
end

---Filters items by matching their value against Vim regular expressions.
---@param opts lese.builtin.refiner.RegexpOptions
---@return lese.Refiner
return function(opts)
  if not opts or (opts.includes == nil and opts.excludes == nil) then
    error("builtin.refiner.regexp needs 'includes' or 'excludes'", 2)
  end
  local includes, excludes = opts.includes, opts.excludes

  return define.refiner({
    name = "builtin.refiner.regexp",
    refine = function(ctx, item)
      local fn = ctx.host.fn
      if includes and not matches_any(fn, item.value, includes) then
        return nil
      end
      if excludes and matches_any(fn, item.value, excludes) then
        return nil
      end
      return item
    end,
  })
end
