-- The themes fall shipped. A border lists topleft, top, topright, right,
-- botright, bottom, botleft, left; a divider lists left, horizontal, right,
-- top, vertical, bottom.

---@class lese.builtin.Theme
---@field MODERN lese.Theme   -- rounded corners, dashed dividers, Nerd Fonts icons
---@field SINGLE lese.Theme
---@field DOUBLE lese.Theme
---@field ASCII lese.Theme    -- for terminals without box-drawing characters
local M = {}

M.MODERN = {
  border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  divider = { "├", "╌", "┤", "┬", "╎", "┴" },
  matcher_icon = " ",
  sorter_icon = " ",
  renderer_icon = " ",
  previewer_icon = "󰥷 ",
}

M.SINGLE = {
  border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
  divider = { "├", "─", "┤", "┬", "│", "┴" },
}

M.DOUBLE = {
  border = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" },
  divider = { "╠", "═", "╣", "╦", "║", "╩" },
}

M.ASCII = {
  border = { ".", "-", ".", "|", "'", "-", "'", "|" },
  divider = { "|", "~", "|", "-", ":", "-" },
  spinner = { "-", "\\", "|", "/" },
  head_symbol = ">",
  fail_symbol = "X",
  matcher_icon = "m:",
  sorter_icon = "s:",
  renderer_icon = "r:",
  previewer_icon = "p:",
}

return M
