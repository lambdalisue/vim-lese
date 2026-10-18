-- Make a table whose missing fields load `<prefix>.<field>` on first access,
-- so `builtin.source.file` requires lese.builtin.source.file only when used.

---@generic T: table
---@param prefix string
---@param base T fields that are not modules (default action sets, themes)
---@return T
return function(prefix, base)
  return setmetatable(base, {
    __index = function(t, name)
      local ok, mod = pcall(require, prefix .. "." .. name)
      if not ok then
        if string.find(tostring(mod), "module '" .. prefix .. "." .. name .. "' not found", 1, true) then
          error(string.format("lese: %s has no '%s'", prefix, tostring(name)), 2)
        end
        error(mod, 0)
      end
      rawset(t, name, mod)
      return mod
    end,
  })
end
