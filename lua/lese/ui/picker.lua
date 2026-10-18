-- A picker on screen: the input, list, preview and help windows around a
-- lese.core.picker model, driven by the command line and <Plug> mappings.

local host = require("lese.host")
local scheduler_mod = require("lese.core.scheduler")
local picker_mod = require("lese.core.picker")
local contract = require("lese.core.contract")
local component = require("lese.ui.component")
local event = require("lese.ui.event")
local view = require("lese.ui.view")

local M = {}

M.ZINDEX_ALLOCATION = 4

---Read the query on the command line; nil when the user cancels. Tests replace
---it, since Vim cannot run input() without a terminal.
---@type fun(picker: lese.UiPicker): string?
M.read = function(picker)
  return host.call("lese#internal#cmdline#input", picker.model.query)
end

local TICK_INTERVAL = 10
local PREVIEW_DELAY = 150
local SPINNER_INTERVAL = 100
local HELP_WIDTH_RATIO = 0.98
local HELP_HEIGHT_RATIO = 0.3

---@class lese.UiPickerParams
---@field name string
---@field source lese.Source
---@field matchers lese.Matcher[]
---@field sorters? lese.Sorter[]
---@field renderers? lese.Renderer[]
---@field previewers? lese.Previewer[]
---@field coordinator lese.Coordinator
---@field theme lese.Theme
---@field args? string[]
---@field zindex integer
---@field context? lese.PickerContext

---@class lese.PickerResult: lese.InvokeParams
---@field action? string   -- the action asked for by lese#action(), if any
---@field _picker? { definition: lese.PickerDefinition, setting: lese.Setting, zindex: integer } -- for builtin.action.submatch

---@class lese.UiPicker: lese.EventHandler
---@field name string
---@field model lese.PickerModel
---@field package scheduler lese.Scheduler
---@field package coordinator lese.Coordinator
---@field package theme lese.Theme
---@field package input lese.Component
---@field package list lese.Component
---@field package preview? lese.Component
---@field package help lese.Component
---@field package dirty table<string, boolean>
---@field package cmdpos integer
---@field package input_offset integer
---@field package action? string
---@field preview_due? number         -- when the cursor row is previewed next
---@field package help_pages? lese.Frame[]
---@field package help_page integer
---@field package started boolean
---@field package running boolean
---@field package autocmd_id? integer
---@field package list_line integer
local Picker = {}
Picker.__index = Picker

local function warn(message)
  host.echo("[lese] " .. message, "WarningMsg")
end

---@param params lese.UiPickerParams
---@return lese.UiPicker
function M.new(params)
  local self = setmetatable({
    name = params.name,
    coordinator = params.coordinator,
    theme = params.theme,
    dirty = {},
    cmdpos = 1,
    input_offset = 0,
    help_page = 1,
    started = false,
    running = false,
    list_line = 0,
  }, Picker)
  self.scheduler = scheduler_mod.new({
    defer = host.defer,
    on_starve = function(task, elapsed)
      if contract.strict then
        warn(
          string.format(
            "%s ran %d ms without ctx:checkpoint(), freezing the editor",
            task.name,
            elapsed
          )
        )
      end
    end,
  })
  self.model = picker_mod.new({
    name = params.name,
    source = params.source,
    matchers = params.matchers,
    sorters = params.sorters,
    renderers = params.renderers,
    previewers = params.previewers,
    args = params.args,
    context = params.context,
    scheduler = self.scheduler,
    host = host,
    on_update = function(kind)
      self:on_update(kind)
    end,
    on_error = function(stage, message)
      warn(string.format("failed to %s: %s", stage, message))
    end,
  })
  self.cmdpos = #self.model.query + 1

  local style = self.coordinator.style(self.theme)
  local zindex = params.zindex
  local title = params.name
  if params.args and #params.args > 0 then
    title = title .. ":" .. table.concat(params.args, " ")
  end
  self.input = component.new({
    border = style.input,
    title = title,
    zindex = zindex,
    options = "nocursorline signcolumn=no nowrap nolist nofoldenable nonumber norelativenumber filetype=lese-input",
  })
  self.list = component.new({
    border = style.list,
    zindex = zindex + 1,
    options = "cursorline cursorlineopt=line signcolumn=yes nowrap nolist nofoldenable nonumber norelativenumber filetype=lese-list",
  })
  if style.preview then
    self.preview = component.new({
      border = style.preview,
      zindex = zindex + 2,
      options = "signcolumn=no nofoldenable",
    })
  end
  self.help = component.new({
    border = self.theme.border,
    title = "Help",
    zindex = zindex + 3,
    options = "nocursorline signcolumn=no nowrap nolist nofoldenable nonumber norelativenumber filetype=lese-help",
  })
  return self
end

---Start from `query` instead of an empty one.
---@param query string
function Picker:set_query(query)
  self.model.query = query
  self.cmdpos = #query + 1
end

function Picker:on_update(kind)
  if kind == "query" or kind == "collect" or kind == "status" then
    self.dirty.input = true
  elseif kind == "render" or kind == "selection" then
    self.dirty.list = true
    self.dirty.input = true
  elseif kind == "indicator" then
    self.dirty.title = true
  elseif kind == "preview" then
    self.dirty.preview = true
  elseif kind == "cursor" then
    self.preview_due = host.now() + PREVIEW_DELAY
  end
end

function Picker:screen()
  return host.screen()
end

function Picker:help_dimension(screen)
  local width = math.floor(screen.width * HELP_WIDTH_RATIO)
  local height = math.floor(screen.height * HELP_HEIGHT_RATIO)
  return {
    row = math.floor(screen.height - height - 2),
    col = math.floor((screen.width - width) / 2),
    width = width,
    height = height,
  }
end

---Open the windows and announce the picker with LesePickerEnterSystem:{name}.
function Picker:open()
  local layout = self.coordinator.layout(self:screen())
  self.input:open(layout.input)
  self.list:open(layout.list)
  if self.preview and layout.preview then
    self.preview:open(layout.preview)
  end
  self.model:set_height(layout.list.height)
  self.list.title = view.indicator(self.model, self.theme)
  self.dirty.title = true
  self.dirty.input = true
  self.dirty.list = true
  self.dirty.preview = true

  self.autocmd_id = host.register(function()
    self:relayout()
  end)
  host.cmd(string.format("augroup lese_ui_picker_%d", self.autocmd_id))
  host.cmd("autocmd!")
  host.cmd(string.format("autocmd VimResized * call lese#internal#invoke(%d)", self.autocmd_id))
  host.cmd("augroup END")
  host.emit("LesePickerEnterSystem:" .. self.name)
end

function Picker:relayout()
  local screen = self:screen()
  local layout = self.coordinator.layout(screen)
  self.input:move(layout.input)
  self.list:move(layout.list)
  if self.preview and layout.preview then
    self.preview:move(layout.preview)
  end
  if self.help.window then
    local dimension = self:help_dimension(screen)
    self.help:move(dimension)
    self.help_pages = view.help_pages(
      host.call("lese#internal#mapping#list"),
      dimension.width,
      dimension.height - 1
    )
  end
  self.model:set_height(layout.list.height)
  self.dirty.input, self.dirty.list, self.dirty.preview, self.dirty.help = true, true, true, true
  self:render()
end

---Close the windows and announce it with LesePickerLeaveSystem:{name}.
function Picker:close()
  if self.autocmd_id then
    host.cmd(string.format("augroup lese_ui_picker_%d", self.autocmd_id))
    host.cmd("autocmd!")
    host.cmd("augroup END")
    host.cmd(string.format("augroup! lese_ui_picker_%d", self.autocmd_id))
    host.unregister(self.autocmd_id)
    self.autocmd_id = nil
  end
  self.input:close()
  self.list:close()
  if self.preview then
    self.preview:close()
  end
  self.help:close()
  host.emit("LesePickerLeaveSystem:" .. self.name)
end

---Stop the work in progress for good.
function Picker:dispose()
  self.model:dispose()
end

function Picker:spinner()
  local frames = self.theme.spinner or view.SPINNER
  return frames[math.floor(host.now() / SPINNER_INTERVAL) % #frames + 1]
end

function Picker:render_input()
  local model = self.model
  local busy = model.collecting == true or model.processing == true
  if not self.dirty.input and not busy then
    return false
  end
  self.dirty.input = false
  if not self.input.dimension then
    return false
  end
  local frame, offset = view.input({
    query = model.query,
    cmdpos = self.cmdpos,
    offset = self.input_offset,
    collected = #model.collected,
    processed = #model.filtered,
    truncated = model.truncated,
    collecting = model.collecting,
    processing = model.processing,
    spinner = self:spinner(),
    head_symbol = self.theme.head_symbol,
    fail_symbol = self.theme.fail_symbol,
  }, self.input.dimension.width)
  self.input_offset = offset
  return self.input:show(frame)
end

function Picker:render_list()
  if not self.dirty.list then
    return false
  end
  self.dirty.list = false
  local model = self.model
  local changed = self.list:show(view.list(model.visible))
  if self.list.window then
    self.list.window:place_signs(
      "LeseListSelectedSign",
      view.selected_lines(model.visible, model.selection)
    )
    local line = model:line()
    if changed or line ~= self.list_line then
      self.list_line = line
      self.list:execute(string.format("silent! normal! %dG", math.max(1, line)))
    end
  end
  return true
end

function Picker:render_preview()
  if not self.dirty.preview or not self.preview or not self.preview.window then
    return false
  end
  self.dirty.preview = false
  local item = self.model.preview or {}
  local content = item.content or { "No preview" }
  self.preview:show({ lines = content, decorations = {} })
  local filename = item.filename or "noname"
  local fname = host.fn.fnameescape("lese://preview/" .. filename)
  local window = self.preview.window --[[@as lese.Window]]
  window:execute("silent! 0file")
  window:execute("silent! syntax clear")
  window:execute("silent! file " .. fname)
  window:execute("silent! setlocal winfixbuf winfixwidth winfixheight")
  window:execute(
    string.format(
      "call lese#internal#highlight#fast('%s')",
      ((item.filetype or ""):gsub("'", "''"))
    )
  )
  window:execute(
    "silent! setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nomodifiable nowrap cursorline cursorlineopt=number,line"
  )
  window:execute(string.format("silent! normal! %dG%d|", item.line or 1, item.column or 1))
  window:execute(
    "silent! call lese#internal#emit(" .. host.fn.string("LesePreviewRendered:" .. filename) .. ")"
  )
  return true
end

function Picker:render_help()
  if not self.dirty.help or not self.help.window or not self.help.dimension then
    return false
  end
  self.dirty.help = false
  local pages = self.help_pages or {}
  local count = math.max(1, #pages)
  self.help_page = math.max(1, math.min(self.help_page, count))
  local page = pages[self.help_page] or { lines = {}, decorations = {} }
  local width = self.help.dimension.width
  local navigator = {}
  for _, m in ipairs(host.call("lese#internal#mapping#list")) do
    if m.rhs == "<Plug>(lese-help-prev)" or m.rhs == "<Plug>(lese-help-next)" then
      navigator[#navigator + 1] = m.lhs
    end
  end
  local pager = string.format("Page %d/%d", self.help_page, count)
  local nav = table.concat(navigator, " / ")
  local header = pager .. string.rep(" ", math.max(1, width - #pager - #nav)) .. nav
  local lines = { header }
  local decorations = { { line = 1, column = 1, length = #header, highlight = "LeseHelpHeader" } }
  for _, line in ipairs(page.lines) do
    lines[#lines + 1] = line
  end
  for _, d in ipairs(page.decorations) do
    decorations[#decorations + 1] =
      { line = d.line + 1, column = d.column, length = d.length, highlight = d.highlight }
  end
  return self.help:show({ lines = lines, decorations = decorations })
end

---Put what changed on screen.
function Picker:render()
  local changed = false
  if self.dirty.title then
    self.dirty.title = false
    self.list.title = view.indicator(self.model, self.theme)
    changed = self.list:update_title() or changed
  end
  changed = self:render_input() or changed
  changed = self:render_list() or changed
  changed = self:render_preview() or changed
  changed = self:render_help() or changed
  if changed then
    host.cmd("redraw")
  end
end

function Picker:sync_cmdline()
  local state = host.call("lese#internal#cmdline#state")
  if not state then
    return
  end
  local cmdline, cmdpos = state[1], state[2]
  if cmdline:find("[%z\1-\31\127]") then
    cmdline = cmdline:gsub("[%z\1-\31\127]", "")
    host.call("lese#internal#cmdline#set", cmdline)
  end
  if cmdpos ~= self.cmdpos then
    self.cmdpos = cmdpos
    self.dirty.input = true
  end
  self.model:set_query(cmdline)
end

---Catch up with the command line, start a due preview and draw what changed.
function Picker:tick()
  local ok, err = pcall(function()
    self:sync_cmdline()
    if self.preview_due and host.now() >= self.preview_due then
      self.preview_due = nil
      self.model:request_preview()
    end
    self:render()
  end)
  if not ok then
    warn(tostring(err))
  end
end

function Picker:loop()
  if not self.running then
    return
  end
  self:tick()
  host.defer(TICK_INTERVAL, function()
    self:loop()
  end)
end

---Read the query until the user accepts or cancels. Returns nil on cancel.
---@return lese.PickerResult?
function Picker:start()
  if not self.started then
    self.started = true
    self.model:start()
  end
  self.action = nil
  self.running = true
  event.push(self)
  self.dirty.input, self.dirty.list = true, true
  self:render()
  host.defer(TICK_INTERVAL, function()
    self:loop()
  end)
  local ok, query = pcall(M.read, self)
  self.running = false
  event.pop(self)
  if not ok then
    error(query, 0)
  end
  if type(query) ~= "string" then
    return nil
  end
  self.model:set_query(query)
  self:settle()
  local result = self.model:result() --[[@as lese.PickerResult]]
  result.action = self.action
  return result
end

---Let matching, sorting and rendering catch up with the final query.
function Picker:settle()
  local model = self.model
  local deadline = host.now() + 3000
  local function settled()
    return model:settled()
  end
  while not settled() and host.now() < deadline do
    self.scheduler:drain(1)
    if not settled() then
      host.wait(5, settled)
    end
  end
end

local function index_of(value)
  if value == "$" then
    return "$"
  end
  return (value or 0) + 1
end

---Handle an event from a <Plug> mapping.
---@param e table
function Picker:handle(e)
  local model = self.model
  local kind = e.type
  if kind == "move-cursor" then
    local amount = e.amount
    if e.scroll then
      amount = amount * math.max(1, math.floor(model.height / 2))
    end
    model:move_cursor(amount)
  elseif kind == "move-cursor-at" then
    model:move_cursor_at(index_of(e.cursor))
  elseif kind == "select-item" then
    model:select(e.cursor ~= nil and index_of(e.cursor) or nil, e.method)
  elseif kind == "select-all-items" then
    model:select_all(e.method)
  elseif kind == "switch-matcher" then
    model:switch_matcher(e.amount, e.cycle)
  elseif kind == "switch-matcher-at" then
    model:switch_matcher_at(index_of(e.index))
  elseif kind == "switch-sorter" then
    model:switch_sorter(e.amount, e.cycle)
  elseif kind == "switch-sorter-at" then
    model:switch_sorter_at(index_of(e.index))
  elseif kind == "switch-renderer" then
    model:switch_renderer(e.amount, e.cycle)
  elseif kind == "switch-renderer-at" then
    model:switch_renderer_at(index_of(e.index))
  elseif kind == "switch-previewer" then
    model:switch_previewer(e.amount, e.cycle)
  elseif kind == "switch-previewer-at" then
    model:switch_previewer_at(index_of(e.index))
  elseif kind == "action-invoke" then
    self.action = e.name
    host.call("lese#internal#cmdline#accept")
  elseif kind == "list-component-execute" then
    self.list:execute(e.command)
    host.cmd("redraw")
  elseif kind == "preview-component-execute" then
    if self.preview then
      self.preview:execute(e.command)
      host.cmd("redraw")
    end
  elseif kind == "help-component-toggle" then
    self:toggle_help()
  elseif kind == "help-component-page" then
    self.help_page = self.help_page + e.amount
    self.dirty.help = true
  end
  self:render()
end

function Picker:toggle_help()
  if self.help.window then
    self.help:close()
    host.cmd("redraw")
    return
  end
  local dimension = self:help_dimension(self:screen())
  self.help_pages =
    view.help_pages(host.call("lese#internal#mapping#list"), dimension.width, dimension.height - 1)
  self.help:open(dimension)
  self.dirty.help = true
end

return M
