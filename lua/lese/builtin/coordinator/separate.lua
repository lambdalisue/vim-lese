local define = require("lese.define")
local frame = require("lese.builtin._frame")

---Every window in a box of its own: the input, the list below it, and the
---preview on the right.
---@param opts? lese.builtin.coordinator.Options
---@return lese.Coordinator
return function(opts)
  local o = frame.options(opts)
  return define.coordinator({
    name = "builtin.coordinator.separate",
    style = function(theme)
      local b = theme.border
      local box = { b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8] }
      return { input = box, list = box, preview = not o.hide_preview and box or nil }
    end,
    layout = function(screen)
      local f = frame.dimension(o, screen)
      local preview_width = o.hide_preview and 0 or frame.preview_width(o, f.width)
      local main_width = f.width - preview_width
      local input_height = 3
      local layout = {
        input = { row = f.row, col = f.col, width = main_width - 2, height = input_height - 2 },
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
