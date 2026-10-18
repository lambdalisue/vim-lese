-- A picker as stable lines of text: what lese-run prints and t.picker():screen()
-- returns. Each row is marked `>` at the cursor and `*` when selected, and the
-- parts a matcher highlighted are wrapped in brackets.

local view = require("lese.ui.view")

local M = {}

---Wrap the match decorations of `label` in brackets.
---@param label string
---@param decorations lese.Decoration[]
---@return string
function M.mark(label, decorations)
  local ranges = {}
  for _, d in ipairs(decorations or {}) do
    if (d.highlight == nil or d.highlight == view.HIGHLIGHT_MATCH) and d.length > 0 then
      local first = math.max(1, d.column)
      local last = math.min(#label, d.column + d.length - 1)
      if first <= last then
        ranges[#ranges + 1] = { first, last }
      end
    end
  end
  if #ranges == 0 then
    return label
  end
  table.sort(ranges, function(a, b)
    return a[1] < b[1]
  end)
  local merged = { ranges[1] }
  for i = 2, #ranges do
    local top = merged[#merged]
    if ranges[i][1] <= top[2] + 1 then
      top[2] = math.max(top[2], ranges[i][2])
    else
      merged[#merged + 1] = ranges[i]
    end
  end
  local parts, pos = {}, 1
  for _, r in ipairs(merged) do
    parts[#parts + 1] = label:sub(pos, r[1] - 1)
    parts[#parts + 1] = "[" .. label:sub(r[1], r[2]) .. "]"
    pos = r[2] + 1
  end
  parts[#parts + 1] = label:sub(pos)
  return table.concat(parts)
end

local function status(value)
  if value == "failed" then
    return " (failed)"
  end
  return ""
end

---@param model lese.PickerModel
---@return string
function M.header(model)
  local name = model.name
  if #model.args > 0 then
    name = name .. ":" .. table.concat(model.args, " ")
  end
  return string.format(
    "%s > %s  %d/%d%s%s%s",
    name,
    model.query,
    #model.filtered,
    #model.collected,
    model.truncated and "+" or "",
    status(model.collecting),
    status(model.processing)
  )
end

---The header and the rows on screen.
---@param model lese.PickerModel
---@return string[]
function M.lines(model)
  local lines = { M.header(model) }
  local line = model:line()
  for i, item in ipairs(model.visible) do
    local cursor = i == line and ">" or " "
    local selected = (item.id ~= nil and model.selection[item.id]) and "*" or " "
    lines[#lines + 1] = cursor .. selected .. M.mark(item.label or item.value, item.decorations)
  end
  return lines
end

---A preview item as lines: a header, then its content.
---@param preview lese.PreviewItem?
---@return string[]
function M.preview(preview)
  if not preview then
    return { "--- no preview ---" }
  end
  local meta = {}
  for _, key in ipairs({ "filename", "filetype", "line", "column" }) do
    if preview[key] ~= nil then
      meta[#meta + 1] = key .. "=" .. tostring(preview[key])
    end
  end
  local lines = { "--- preview " .. table.concat(meta, " ") .. " ---" }
  for _, l in ipairs(preview.content) do
    lines[#lines + 1] = l
  end
  return lines
end

return M
