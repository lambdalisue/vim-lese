-- The modules lese ships, grouped by kind: `builtin.source.file()`,
-- `builtin.matcher.fzf()`, `builtin.theme.MODERN`. A kind is loaded on first
-- use, so custom.lua pays only for what it names.

---@class lese.Builtin
---@field source lese.builtin.Source
---@field curator lese.builtin.Curator
---@field matcher lese.builtin.Matcher
---@field sorter lese.builtin.Sorter
---@field renderer lese.builtin.Renderer
---@field previewer lese.builtin.Previewer
---@field action lese.builtin.Action
---@field refiner lese.builtin.Refiner
---@field coordinator lese.builtin.Coordinator
---@field theme lese.builtin.Theme
local M = {}

local KINDS = {
  source = true,
  curator = true,
  matcher = true,
  sorter = true,
  renderer = true,
  previewer = true,
  action = true,
  refiner = true,
  coordinator = true,
  theme = true,
}

return setmetatable(M, {
  __index = function(t, kind)
    if not KINDS[kind] then
      error(string.format("lese: there is no builtin kind '%s'", tostring(kind)), 2)
    end
    local mod = require("lese.builtin." .. kind)
    rawset(t, kind, mod)
    return mod
  end,
})
