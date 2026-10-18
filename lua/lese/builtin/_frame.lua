-- The centred frame every built-in coordinator lays its windows out in.

local M = {}

---@class lese.builtin.coordinator.Options
---@field hide_preview? boolean  -- default false
---@field width_ratio? number    -- of the screen width, default 0.8
---@field width_min? integer     -- default 10
---@field width_max? integer     -- default 340
---@field height_ratio? number   -- of the screen height, default 0.6
---@field height_min? integer    -- default 5
---@field height_max? integer    -- default 70
---@field preview_ratio? number  -- of the frame width, default 0.6

---@param opts? lese.builtin.coordinator.Options
---@return lese.builtin.coordinator.Options
function M.options(opts)
  opts = opts or {}
  return {
    hide_preview = opts.hide_preview == true,
    width_ratio = opts.width_ratio or 0.8,
    width_min = opts.width_min or 10,
    width_max = opts.width_max or 340,
    height_ratio = opts.height_ratio or 0.6,
    height_min = opts.height_min or 5,
    height_max = opts.height_max or 70,
    preview_ratio = opts.preview_ratio or 0.6,
  }
end

---The frame's outer size and its 1-based top-left corner, centred on screen.
---@param opts lese.builtin.coordinator.Options
---@param screen lese.Size
---@return { row: integer, col: integer, width: integer, height: integer }
function M.dimension(opts, screen)
  local width =
    math.min(opts.width_max, math.max(opts.width_min, math.floor(screen.width * opts.width_ratio)))
  local height = math.min(
    opts.height_max,
    math.max(opts.height_min, math.floor(screen.height * opts.height_ratio))
  )
  return {
    row = 1 + math.floor((screen.height - height) / 2),
    col = 1 + math.floor((screen.width - width) / 2),
    width = width,
    height = height,
  }
end

---The outer width of the preview in a frame `width` wide.
---@param opts lese.builtin.coordinator.Options
---@param width integer
---@return integer
function M.preview_width(opts, width)
  return math.max(0, math.floor(width * opts.preview_ratio))
end

return M
