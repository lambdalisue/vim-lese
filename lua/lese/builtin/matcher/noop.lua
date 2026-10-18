local define = require("lese.define")

---A matcher that lets nothing through: a placeholder where one is required.
---@return lese.Matcher
return function()
  return define.matcher({
    name = "builtin.matcher.noop",
    match = function() end,
  })
end
