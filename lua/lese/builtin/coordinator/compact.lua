local define = require("lese.define")
local frame = require("lese.builtin._frame")

---Like modern, but the windows share their borders: one box split by the
---dividers.
---@param opts? lese.builtin.coordinator.Options
---@return lese.Coordinator
return function(opts)
  local o = frame.options(opts)
  return define.coordinator({
    name = "builtin.coordinator.compact",
    style = function(theme)
      local b, d = theme.border, theme.divider
      if o.hide_preview then
        return {
          input = { b[1], b[2], b[3], b[4], "", "", "", b[8] },
          list = { d[1], d[2], d[3], b[4], b[5], b[6], b[7], b[8] },
        }
      end
      return {
        input = { b[1], b[2], d[4], d[5], "", "", "", b[8] },
        list = { d[1], d[2], "", "", "", b[6], b[7], b[8] },
        preview = { d[4], b[2], b[3], b[4], b[5], b[6], d[6], d[5] },
      }
    end,
    layout = function(screen)
      local f = frame.dimension(o, screen)
      local input_height = 2
      if o.hide_preview then
        return {
          input = { row = f.row, col = f.col, width = f.width - 2, height = input_height - 1 },
          list = {
            row = f.row + input_height,
            col = f.col,
            width = f.width - 2,
            height = f.height - input_height - 2,
          },
        }
      end
      local preview_width = frame.preview_width(o, f.width)
      local main_width = f.width - preview_width
      return {
        input = { row = f.row, col = f.col, width = main_width - 1, height = input_height - 1 },
        list = {
          row = f.row + input_height,
          col = f.col,
          width = main_width - 1,
          height = f.height - input_height - 2,
        },
        preview = {
          row = f.row,
          col = f.col + main_width,
          width = preview_width - 2,
          height = f.height - 2,
        },
      }
    end,
  })
end
