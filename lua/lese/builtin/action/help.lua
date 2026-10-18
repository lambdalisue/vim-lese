local build = require("lese.builtin.action._cmd")

local function attr_getter(item)
  local detail = item.detail
  if detail.lang then
    return detail.helptag .. "@" .. detail.lang
  end
  return detail.helptag
end

---Opens help at `detail.helptag`, in `detail.lang` when set.
---@return lese.Action
return function()
  return build("builtin.action.help", {
    attr_getter = attr_getter,
    immediate = true,
    template = "help {}",
  })
end
