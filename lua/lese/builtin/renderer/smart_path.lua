local define = require("lese.define")

local COMMENT = "Comment"

---Show a path label as "file dir", with the directory dimmed, so the file
---name lines up at the start of every row.
---@return lese.Renderer
return function()
  return define.renderer({
    name = "builtin.renderer.smart_path",
    render = function(ctx, params)
      for i, item in ipairs(params.items) do
        if i % 256 == 0 then
          ctx:checkpoint()
        end
        local text = item.label
        local sep = string.match(text, "^.*()[/\\]")
        if sep then
          local filename = string.sub(text, sep + 1)
          local dirname = string.sub(text, 1, sep - 1)
          local file_len = #filename
          local decorations = {}
          local function add(column, length, highlight)
            if length > 0 then
              decorations[#decorations + 1] =
                { column = column, length = length, highlight = highlight }
            end
          end
          for _, d in ipairs(item.decorations or {}) do
            local s, e = d.column, d.column + d.length - 1
            -- The directory part moves after "file ", the file part to the start.
            add(s + file_len + 1, math.min(e, sep - 1) - s + 1, d.highlight)
            local fs = math.max(s, sep + 1)
            add(fs - sep, e - fs + 1, d.highlight)
          end
          add(file_len + 1, #dirname + 1, COMMENT)
          item.label = filename .. " " .. dirname
          item.decorations = decorations
        end
      end
    end,
  })
end
