-- The modules lese ships, grouped by kind: `builtin.source.file()`,
-- `builtin.matcher.fzf()`, `builtin.theme.MODERN`. A kind is loaded on first
-- use, so custom.lua pays only for what it names.

---The modules lese ships, grouped by kind. Factories are called to get a module (`builtin.matcher.fzf()`).
---@class lese.Builtin
---@field source lese.builtin.Source           -- sources: collect items once per picker
---@field curator lese.builtin.Curator         -- curators: search again for each query
---@field matcher lese.builtin.Matcher         -- matchers: filter items by the query
---@field sorter lese.builtin.Sorter           -- sorters: reorder the filtered items
---@field renderer lese.builtin.Renderer       -- renderers: set how the visible items look
---@field previewer lese.builtin.Previewer     -- previewers: show the item under the cursor
---@field action lese.builtin.Action           -- actions, and ready-made `default_*_actions` sets to merge into a picker's `actions`
---@field refiner lese.builtin.Refiner         -- refiners: transform or drop items on their way out of a source or curator
---@field coordinator lese.builtin.Coordinator -- coordinators: lay the picker windows out
---@field theme lese.builtin.Theme             -- themes: plain tables to pass as is, not factories
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
