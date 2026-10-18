local define = require("lese.define")
local icons = require("lese.builtin._nerdfont")
local label = require("lese.builtin._label")

local ASCII_LOWER = {}
for b = 65, 90 do
  ASCII_LOWER[string.char(b)] = string.char(b + 32)
end

local function lower(s)
  return (string.gsub(s, "[A-Z]", ASCII_LOWER))
end

---@param path string
---@return string
local function icon_for(path)
  for _, entry in ipairs(icons.pattern) do
    if string.find(path, entry[1]) then
      return entry[2]
    end
  end
  local base = lower(string.match(path, "([^/\\]*)$"))
  local icon = icons.basename[base]
  if icon then
    return icon
  end
  local ext = string.match(base, "^.+%.([^.]+)$")
  return ext and icons.extension[ext] or icons.extension["."]
end

---Put a Nerd Fonts icon for `item.detail.path` (by pattern, file name, then
---extension) and two spaces before the label. The icons need a Nerd Font.
---@return lese.Renderer
return function()
  return define.renderer({
    name = "builtin.renderer.nerdfont",
    render = function(ctx, params)
      for i, item in ipairs(params.items) do
        if i % 256 == 0 then
          ctx:checkpoint()
        end
        local prefix = icon_for(item.detail.path or item.value) .. "  "
        item.label = prefix .. item.label
        item.decorations = label.shift(item.decorations or {}, #prefix)
      end
    end,
  })
end
