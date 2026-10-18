local define = require("lese.define")
local frame = require("lese.builtin._frame")

---The input above the list in one box, split by the divider, and the preview
---in its own box on the right.
---@param opts? lese.builtin.coordinator.Options
---@return lese.Coordinator
return function(opts)
  local o = frame.options(opts)
  return define.coordinator({
    name = "builtin.coordinator.modern",
    style = function(theme)
      local b, d = theme.border, theme.divider
      return {
        input = { b[1], b[2], b[3], b[4], "", "", "", b[8] },
        list = { d[1], d[2], d[3], b[4], b[5], b[6], b[7], b[8] },
        preview = not o.hide_preview and { b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8] } or nil,
      }
    end,
    layout = function(screen)
      local f = frame.dimension(o, screen)
      local preview_width = o.hide_preview and 0 or frame.preview_width(o, f.width)
      local main_width = f.width - preview_width
      local input_height = 2
      local layout = {
        input = { row = f.row, col = f.col, width = main_width - 2, height = input_height - 1 },
        list = {
          row = f.row + input_height,
          col = f.col,
          width = main_width - 2,
          height = f.height - input_height - 2,
        },
      }
      if not o.hide_preview then
        layout.preview = {
          row = f.row,
          col = f.col + main_width,
          width = preview_width - 2,
          height = f.height - 2,
        }
      end
      return layout
    end,
  })
end
