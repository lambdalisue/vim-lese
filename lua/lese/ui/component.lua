-- A picker window: opens, moves and closes a host window and puts frames on
-- it, skipping a frame identical to the one already shown.

local host = require("lese.host")

local M = {}

---@class lese.Component
---@field window? lese.Window
---@field dimension? lese.Dimension
---@field border? lese.Border
---@field title string
---@field zindex integer
---@field options string        -- `setlocal` arguments applied when it opens
---@field package shown? string  -- the last frame put on screen, serialised
---@field package shown_title? string
local Component = {}
Component.__index = Component

---@param opts { border?: lese.Border, title?: string, zindex: integer, options?: string }
---@return lese.Component
function M.new(opts)
  return setmetatable({
    border = opts.border,
    title = opts.title or "",
    zindex = opts.zindex,
    options = opts.options or "",
  }, Component)
end

local function decorated_title(title)
  if title == "" then
    return ""
  end
  return " " .. title .. " "
end

---@param dimension lese.Dimension
function Component:open(dimension)
  if self.window then
    return
  end
  self.dimension = dimension
  self.window = host.open_window(dimension, {
    border = self.border,
    title = decorated_title(self.title),
    zindex = self.zindex,
    highlight = { normal = "LeseNormal", border = "LeseBorder" },
  })
  self.shown_title = self.title
  if self.options ~= "" then
    self.window:execute("setlocal " .. self.options)
  end
  self.shown = nil
end

---@param dimension lese.Dimension
function Component:move(dimension)
  self.dimension = dimension
  if self.window then
    self.window:config(dimension, nil)
    self.shown = nil
  end
end

---@return boolean changed
function Component:update_title()
  if self.window and self.shown_title ~= self.title then
    self.shown_title = self.title
    if self.title ~= "" then
      self.window:config(nil, { title = decorated_title(self.title) })
    end
    return true
  end
  return false
end

local function serialise(frame)
  local parts = { table.concat(frame.lines, "\n") }
  for _, d in ipairs(frame.decorations) do
    parts[#parts + 1] = d.line .. ":" .. d.column .. ":" .. d.length .. ":" .. d.highlight
  end
  return table.concat(parts, "\0")
end

---Show `frame`. Returns false when it was already shown.
---@param frame lese.Frame
---@return boolean changed
function Component:show(frame)
  if not self.window then
    return false
  end
  local key = serialise(frame)
  if key == self.shown then
    return false
  end
  self.shown = key
  self.window:set_lines(frame.lines)
  self.window:undecorate()
  self.window:decorate(frame.decorations)
  return true
end

---Run an Ex command in the window.
---@param command string
function Component:execute(command)
  if self.window then
    self.window:execute(command)
  end
end

function Component:close()
  if self.window then
    self.window:close()
    self.window = nil
    self.shown = nil
  end
end

return M
