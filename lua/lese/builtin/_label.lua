-- Rewrite part of a rendered label while keeping its decorations on the same
-- characters. Shared by the built-in renderers.

local M = {}

---Replace `length` bytes of `item.label` from `column` with `text`.
---Decorations after the span move with it; decorations inside it are aligned
---to its end, where a path keeps its file name, and trimmed to the new span.
---@param item lese.Item
---@param column integer
---@param length integer
---@param text string
function M.replace(item, column, length, text)
  local label = item.label or item.value
  local old_end = column + length - 1
  local new_end = column + #text - 1
  local delta = #text - length
  item.label = string.sub(label, 1, column - 1) .. text .. string.sub(label, old_end + 1)
  local decorations = {}
  for _, d in ipairs(item.decorations or {}) do
    local s, e = d.column, d.column + d.length - 1
    if e < column then
      decorations[#decorations + 1] = d
    elseif s > old_end then
      decorations[#decorations + 1] =
        { column = s + delta, length = d.length, highlight = d.highlight }
    else
      s, e = math.max(s + delta, column), math.min(e + delta, new_end)
      if e >= s then
        decorations[#decorations + 1] = { column = s, length = e - s + 1, highlight = d.highlight }
      end
    end
  end
  item.decorations = decorations
end

---Move every decoration `offset` bytes to the right.
---@param decorations lese.Decoration[]
---@param offset integer
---@return lese.Decoration[]
function M.shift(decorations, offset)
  local shifted = {}
  for i, d in ipairs(decorations) do
    shifted[i] = { column = d.column + offset, length = d.length, highlight = d.highlight }
  end
  return shifted
end

return M
