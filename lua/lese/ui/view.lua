-- What each picker window shows, computed without touching a window: lines,
-- decorations and the cursor row. lese.ui.picker puts the result on screen and
-- lese.testing turns it into text.

local text = require("lese.core.text")

local M = {}

M.HIGHLIGHT_HEADER = "LeseInputHeader"
M.HIGHLIGHT_CURSOR = "LeseInputCursor"
M.HIGHLIGHT_COUNTER = "LeseInputCounter"
M.HIGHLIGHT_MATCH = "LeseListMatch"

M.HEAD_SYMBOL = ">"
M.FAIL_SYMBOL = "✕"
M.SPINNER = { "⣾", "⣷", "⣯", "⣟", "⡿", "⢿", "⣻", "⣽" }

M.MATCHER_ICON = "🅼 "
M.SORTER_ICON = "🆂 "
M.RENDERER_ICON = "🆁 "
M.PREVIEWER_ICON = "🅿 "

---@class lese.InputState
---@field query string
---@field cmdpos integer        -- 1-based byte position of the cursor in the query
---@field offset integer        -- characters scrolled off the left
---@field collected integer
---@field processed integer
---@field truncated boolean
---@field collecting boolean|"failed"
---@field processing boolean|"failed"
---@field spinner string        -- the spinner frame to show
---@field head_symbol? string
---@field fail_symbol? string

---@class lese.Frame
---@field lines string[]
---@field decorations lese.HostDecoration[]

---The single line of the input window.
---@param state lese.InputState
---@param width integer
---@return lese.Frame frame
---@return integer offset the scroll to keep for the next frame
function M.input(state, width)
  local fail = state.fail_symbol or M.FAIL_SYMBOL
  local head
  if state.processing == "failed" then
    head = fail
  elseif state.processing then
    head = state.spinner
  else
    head = state.head_symbol or M.HEAD_SYMBOL
  end
  local prefix = head .. " "
  local tail = ""
  if state.collecting == "failed" then
    tail = fail
  elseif state.collecting then
    tail = state.spinner
  end
  local suffix = string.format(
    " %d/%d%s %s",
    state.processed,
    state.collected,
    state.truncated and "+" or "",
    tail
  )
  suffix = suffix:gsub("%s+$", "")
  local available = math.max(1, width - text.width(prefix) - text.width(suffix))

  local chars = text.chars(state.query)
  local cursor, consumed = 0, 1
  for _, c in ipairs(chars) do
    if consumed >= state.cmdpos then
      break
    end
    consumed = consumed + #c[1]
    cursor = cursor + 1
  end
  local offset = state.offset
  if cursor < offset then
    offset = cursor
  elseif cursor - offset >= available then
    offset = cursor - available + 1
  end

  local parts, used = {}, 0
  local cursor_byte, cursor_len = nil, 1
  local bytes = #prefix
  for i = offset + 1, #chars do
    local c = chars[i]
    if used + c[2] > available then
      break
    end
    if i == cursor + 1 then
      cursor_byte, cursor_len = bytes + 1, #c[1]
    end
    parts[#parts + 1] = c[1]
    used = used + c[2]
    bytes = bytes + #c[1]
  end
  if not cursor_byte then
    cursor_byte = bytes + 1
  end
  local middle = table.concat(parts) .. string.rep(" ", available - used)
  local line = prefix .. middle .. suffix
  return {
    lines = { line },
    decorations = {
      { line = 1, column = 1, length = #prefix, highlight = M.HIGHLIGHT_HEADER },
      { line = 1, column = cursor_byte, length = cursor_len, highlight = M.HIGHLIGHT_CURSOR },
      {
        line = 1,
        column = #prefix + #middle + 1,
        length = #suffix,
        highlight = M.HIGHLIGHT_COUNTER,
      },
    },
  },
    offset
end

local function sanitize(label)
  if string.find(label, "[%z\n\r]") then
    return (label:gsub("[%z\n\r]", " "))
  end
  return label
end

---The rows of the list window.
---@param items lese.Item[]  -- rendered rows
---@return lese.Frame
function M.list(items)
  local lines, decorations = {}, {}
  for i, item in ipairs(items) do
    local label = sanitize(item.label or item.value)
    lines[i] = label
    for _, d in ipairs(item.decorations or {}) do
      if d.column <= #label and d.length > 0 then
        decorations[#decorations + 1] = {
          line = i,
          column = d.column,
          length = math.min(d.length, #label - d.column + 1),
          highlight = d.highlight or M.HIGHLIGHT_MATCH,
        }
      end
    end
  end
  return { lines = lines, decorations = decorations }
end

---The list rows whose item is selected.
---@param items lese.Item[]
---@param selection table<any, true>
---@return integer[]
function M.selected_lines(items, selection)
  local lines = {}
  for i, item in ipairs(items) do
    if item.id ~= nil and selection[item.id] then
      lines[#lines + 1] = i
    end
  end
  return lines
end

---The indicator of which matcher, sorter, renderer and previewer is in use,
---shown only for the kinds that have more than one.
---@param model lese.PickerModel
---@param theme lese.Theme
---@return string
function M.indicator(model, theme)
  local parts = {}
  local function add(icon, index, count)
    if count > 1 then
      parts[#parts + 1] = icon .. index
    end
  end
  add(theme.matcher_icon or M.MATCHER_ICON, model.matcher_index, #model.matchers)
  add(theme.sorter_icon or M.SORTER_ICON, model.sorter_index, #model.sorters)
  add(theme.renderer_icon or M.RENDERER_ICON, model.renderer_index, #model.renderers)
  add(theme.previewer_icon or M.PREVIEWER_ICON, model.previewer_index, #model.previewers)
  return table.concat(parts, " ")
end

M.HELP_LHS = "LeseHelpMappingLhs"
M.HELP_RHS = "LeseHelpMappingRhs"
M.HELP_OPERATOR = "LeseHelpMappingOperator"

---Name what a command-line mapping does in the picker, or nil when it does not
---reach lese.
---@param rhs string
---@return string?
function M.describe_mapping(rhs)
  local plug = rhs:match("^<Plug>%(lese%-([^)]+)%)$")
  if plug then
    return plug
  end
  local action = rhs:match("^<Cmd>call%s+lese#action%(['\"](.*)['\"]%)<CR>$")
  if action then
    return "action(" .. action .. ")"
  end
  return nil
end

---Lay mappings out in columns, one page per screenful.
---@param mappings { lhs: string, rhs: string }[]
---@param width integer
---@param height integer
---@return lese.Frame[]
function M.help_pages(mappings, width, height)
  local records = {}
  for _, m in ipairs(mappings) do
    local what = M.describe_mapping(m.rhs)
    if what and not m.lhs:match("^<Plug>") then
      records[#records + 1] = { lhs = m.lhs, rhs = what }
    end
  end
  table.sort(records, function(a, b)
    return a.rhs .. a.lhs < b.rhs .. b.lhs
  end)
  if #records == 0 then
    return { { lines = { "No mapping reaches lese." }, decorations = {} } }
  end
  local operator, spacer = " ➙ ", "    "
  local lhs_width, rhs_width = 0, 0
  for _, r in ipairs(records) do
    lhs_width = math.max(lhs_width, text.width(r.lhs))
    rhs_width = math.max(rhs_width, text.width(r.rhs))
  end
  local column_width = math.min(width, lhs_width + rhs_width + text.width(operator) + #spacer)
  local column_count = math.max(1, math.floor(width / column_width))
  local record_width = column_width - #spacer
  height = math.max(1, height)

  local cells = {}
  for i, r in ipairs(records) do
    local cell = string.rep(" ", lhs_width - text.width(r.lhs)) .. r.lhs .. operator .. r.rhs
    if text.width(cell) > record_width then
      cell = text.fit(cell, record_width - 1) .. "…"
    end
    cells[i] = { text = text.fit(cell, record_width, true), lhs = r.lhs }
  end

  local per_page = height * column_count
  local pages = {}
  for first = 1, #cells, per_page do
    local lines, decorations = {}, {}
    for row = 1, height do
      local parts = {}
      local bytes = 0
      for column = 1, column_count do
        local cell = cells[first + (column - 1) * height + row - 1]
        if cell then
          local start = bytes + 1
          local lhs_start = start + (lhs_width - text.width(cell.lhs))
          decorations[#decorations + 1] =
            { line = row, column = lhs_start, length = #cell.lhs, highlight = M.HELP_LHS }
          decorations[#decorations + 1] = {
            line = row,
            column = lhs_start + #cell.lhs,
            length = #operator,
            highlight = M.HELP_OPERATOR,
          }
          decorations[#decorations + 1] = {
            line = row,
            column = lhs_start + #cell.lhs + #operator,
            length = #cell.text - (lhs_start - start) - #cell.lhs - #operator,
            highlight = M.HELP_RHS,
          }
          parts[#parts + 1] = cell.text
          bytes = bytes + #cell.text + #spacer
        end
      end
      if #parts > 0 then
        lines[#lines + 1] = table.concat(parts, spacer)
      end
    end
    pages[#pages + 1] = { lines = lines, decorations = decorations }
  end
  return pages
end

return M
