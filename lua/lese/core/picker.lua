-- The state of one picker and the pipeline behind it: collect → match → sort →
-- render, plus preview. It knows nothing about windows or keys; lese.ui draws
-- it and lese.testing drives it headlessly.

local context = require("lese.core.context")

local M = {}

---@alias lese.Notification "query"|"collect"|"status"|"render"|"selection"|"indicator"|"preview"|"cursor"

---What a picker can be resumed from.
---@class lese.PickerContext
---@field query string               -- the query typed
---@field selection table<any, true> -- selected item ids
---@field collected lese.Item[]      -- every item collected, in the order the source emitted them
---@field filtered lese.Item[]       -- the matched and sorted items the list showed
---@field cursor integer             -- 1-based index into filtered; 0 when empty
---@field offset integer             -- rows scrolled off the top of the list
---@field matcher_index integer      -- 1-based index of the matcher in use
---@field sorter_index integer       -- 1-based index of the sorter in use
---@field renderer_index integer     -- 1-based index of the renderer in use
---@field previewer_index integer    -- 1-based index of the previewer in use

---@class lese.PickerModelParams
---@field name string                                   -- the picker's name, used in errors
---@field source lese.Source                            -- collects the items once
---@field matchers lese.Matcher[]                       -- at least one; the first is used unless context says otherwise
---@field sorters? lese.Sorter[]                        -- default: none, which keeps the matcher's order
---@field renderers? lese.Renderer[]                    -- default: none, which shows the values
---@field previewers? lese.Previewer[]                  -- default: none, which previews nothing
---@field args? string[]                                -- passed to the source, default {}
---@field scheduler lese.Scheduler                      -- runs every module as a task
---@field host? lese.Host                               -- what modules reach as `ctx.host`
---@field height? integer                               -- rows the list shows, default 10
---@field scroll_offset? integer                        -- rows kept above and below the cursor, default 2
---@field threshold? integer                            -- most items collected, default 100000
---@field context? lese.PickerContext
---@field on_update? fun(kind: lese.Notification)       -- told what changed, to redraw that part
---@field on_error? fun(stage: string, message: string) -- told which stage failed and why

---@class lese.PickerModel
---@field name string                 -- the picker's name, used in errors
---@field args string[]               -- passed to the source
---@field query string                -- the query typed so far
---@field collected lese.Item[]       -- in the order the source emitted them
---@field matched lese.Item[]         -- what the matcher let through, in its order
---@field filtered lese.Item[]        -- matched, sorted: what the list shows
---@field visible lese.Item[]         -- rendered copies of the rows on screen
---@field cursor integer              -- 1-based index into filtered; 0 when empty
---@field offset integer              -- filtered[offset + 1] is the first row on screen
---@field height integer              -- rows the list shows
---@field selection table<any, true>  -- selected item ids
---@field collecting boolean|"failed" -- true while the source runs; "failed" when it raised
---@field processing boolean|"failed" -- true while matching or sorting runs; "failed" when a module raised
---@field truncated boolean           -- the source emitted more than the threshold and the rest was dropped
---@field preview? lese.PreviewItem
---@field matchers lese.Matcher[]     -- the matchers to switch between
---@field sorters lese.Sorter[]       -- the sorters to switch between
---@field renderers lese.Renderer[]   -- the renderers to switch between
---@field previewers lese.Previewer[] -- the previewers to switch between
---@field matcher_index integer       -- 1-based index of the matcher in use
---@field sorter_index integer        -- 1-based index of the sorter in use
---@field renderer_index integer      -- 1-based index of the renderer in use
---@field previewer_index integer     -- 1-based index of the previewer in use
---@field package source lese.Source
---@field package scheduler lese.Scheduler
---@field package host? lese.Host
---@field package scroll_offset integer
---@field package threshold integer
---@field package on_update fun(kind: lese.Notification)
---@field package on_error fun(stage: string, message: string)
---@field package resumed boolean
---@field package tasks table<string, lese.Task>
---@field package match_dirty boolean
---@field package matched_query? string
---@field package matched_count integer
---@field package previewed? lese.Item
---@field package match_ended? number
---@field package match_cost? number
---@field package retry_pending? boolean
---@field package disposed? boolean
local Picker = {}
Picker.__index = Picker

local function clamp(value, low, high)
  if value < low then
    return low
  elseif value > high then
    return high
  end
  return value
end

local function copy_list(list, n)
  local out = {}
  for i = 1, n or #list do
    out[i] = list[i]
  end
  return out
end

---Scroll so the cursor keeps `scroll_offset` rows to the top and bottom edges
---where the list allows.
---@param offset integer   -- rows scrolled off the top
---@param cursor integer   -- 0-based
---@param count integer
---@param height integer
---@param scroll_offset integer
---@return integer
function M.adjust_offset(offset, cursor, count, height, scroll_offset)
  if count <= height then
    return 0
  end
  local margin = math.min(scroll_offset, math.floor((height - 1) / 2))
  local view = cursor - offset
  if view > height - 1 - margin then
    offset = cursor - (height - 1 - margin)
  elseif view < margin then
    offset = cursor - margin
  end
  return clamp(offset, 0, count - height)
end

---@param params lese.PickerModelParams
---@return lese.PickerModel
function M.new(params)
  if not params.matchers or #params.matchers == 0 then
    error(string.format("lese: picker '%s' needs at least one matcher", params.name), 2)
  end
  local saved = params.context
  local self = setmetatable({
    name = params.name,
    args = params.args or {},
    source = params.source,
    matchers = params.matchers,
    sorters = params.sorters or {},
    renderers = params.renderers or {},
    previewers = params.previewers or {},
    scheduler = params.scheduler,
    host = params.host,
    height = params.height or 10,
    scroll_offset = params.scroll_offset or 2,
    threshold = params.threshold or 100000,
    on_update = params.on_update or function() end,
    on_error = params.on_error or function() end,
    query = saved and saved.query or "",
    collected = saved and copy_list(saved.collected) or {},
    matched = saved and copy_list(saved.filtered) or {},
    filtered = saved and copy_list(saved.filtered) or {},
    visible = {},
    cursor = saved and saved.cursor or 1,
    offset = saved and saved.offset or 0,
    selection = saved and saved.selection or {},
    collecting = false,
    processing = false,
    truncated = false,
    matcher_index = saved and saved.matcher_index or 1,
    sorter_index = saved and saved.sorter_index or 1,
    renderer_index = saved and saved.renderer_index or 1,
    previewer_index = saved and saved.previewer_index or 1,
    resumed = saved ~= nil,
    tasks = {},
    match_dirty = false,
    matched_query = nil,
    matched_count = -1,
    previewed = nil,
  }, Picker)
  self.matcher_index = clamp(self.matcher_index, 1, #self.matchers)
  self.sorter_index = clamp(self.sorter_index, 1, math.max(1, #self.sorters))
  self.renderer_index = clamp(self.renderer_index, 1, math.max(1, #self.renderers))
  self.previewer_index = clamp(self.previewer_index, 1, math.max(1, #self.previewers))
  return self
end

---Tell `on_update` what changed.
function Picker:notify(kind)
  self.on_update(kind)
end

---A context for running the module `name`, emitting into `sink`.
function Picker:context_for(name, sink)
  return context.new({ scheduler = self.scheduler, host = self.host, name = name, sink = sink })
end

---Run `fn` as the task for `stage`, cancelling the one already running there.
function Picker:run(stage, name, fn, callbacks)
  local previous = self.tasks[stage]
  if previous then
    previous:cancel()
  end
  local task
  task = self.scheduler:spawn(fn, {
    name = name,
    on_done = function()
      if self.tasks[stage] == task then
        self.tasks[stage] = nil
      end
      if callbacks.done then
        callbacks.done()
      end
    end,
    on_error = function(t)
      if self.tasks[stage] == task then
        self.tasks[stage] = nil
      end
      if callbacks.failed then
        callbacks.failed()
      end
      self.on_error(stage, t.traceback or tostring(t.error))
    end,
    on_cancel = function()
      if self.tasks[stage] == task then
        self.tasks[stage] = nil
      end
      if callbacks.cancelled then
        callbacks.cancelled()
      end
    end,
  })
  self.tasks[stage] = task
  return task
end

---True once matching, sorting and rendering caught up; collecting may go on.
---@return boolean
function Picker:settled()
  local tasks = self.tasks
  return not (tasks.match or tasks.sort or tasks.render)
end

---The stages still running, with the module each runs, for messages.
---@return string
function Picker:running()
  local names = {}
  for stage, task in pairs(self.tasks) do
    names[#names + 1] = stage .. "(" .. task.name .. ")"
  end
  table.sort(names)
  return table.concat(names, ", ")
end

---True while any stage still has work.
---@return boolean
function Picker:busy()
  return next(self.tasks) ~= nil
end

---Start collecting, or match what a resumed picker already collected.
function Picker:start()
  if self.resumed then
    self:request_match(true)
    return
  end
  self.collecting = true
  self:notify("status")
  local source = self.source
  local task
  task = self:run("collect", source.name, function()
    local ctx = self:context_for(source.name, function(items)
      local collected = self.collected
      for _, item in ipairs(items) do
        if #collected >= self.threshold then
          self.truncated = true
          task:cancel()
          break
        end
        collected[#collected + 1] = item
      end
      self:notify("collect")
      self:request_match(false)
    end)
    source.collect(ctx, { args = self.args })
  end, {
    done = function()
      self.collecting = false
      self:notify("status")
      self:request_match(false)
    end,
    failed = function()
      self.collecting = "failed"
      self:notify("status")
    end,
    -- Collection stops at the threshold through a cancel, which is not a failure.
    cancelled = function()
      if self.truncated then
        self.collecting = false
        self:notify("status")
        self:request_match(false)
      end
    end,
  })
end

---The matcher in use.
---@return lese.Matcher
function Picker:matcher()
  return self.matchers[self.matcher_index]
end

---Match again. A restart cancels a match in progress; otherwise a match in
---progress finishes and then runs once more with what arrived meanwhile.
---@param restart boolean
function Picker:request_match(restart)
  if self.tasks.match and not restart then
    self.match_dirty = true
    return
  end
  if not restart and self.collecting == true and self:cooling() then
    self.match_dirty = true
    self:retry_match()
    return
  end
  local n = #self.collected
  if not self.tasks.match and self.query == self.matched_query and n == self.matched_count then
    return
  end
  self.match_dirty = false
  local matcher = self:matcher()
  local query = self.query
  local items = self:match_input(matcher, query, n)
  local results = {}
  local started = self.scheduler:now()
  self.processing = true
  self:notify("status")
  self:run("match", matcher.name, function()
    local ctx = self:context_for(matcher.name, function(emitted)
      for _, item in ipairs(emitted) do
        results[#results + 1] = item
      end
      if matcher.incremental and not self.tasks.sort then
        self.matched = copy_list(results)
        self:request_sort()
      end
    end)
    matcher.match(ctx, { query = query, items = items })
  end, {
    done = function()
      self.matched = results
      self.matched_query = query
      self.matched_count = n
      self.match_ended = self:wall()
      self.match_cost = self.scheduler:now() - started
      if self.match_dirty then
        if self.collecting == true then
          self:retry_match()
        else
          self:request_match(false)
        end
      end
      self:request_sort()
    end,
    failed = function()
      self.processing = "failed"
      self:notify("status")
    end,
  })
end

---The items to match `query` against: what the last match let through when
---the matcher says `query` only narrows it and that match saw every item, in
---collection order so the result is the one a full match gives; else every item.
---@param matcher lese.Matcher
---@param query string
---@param n integer  -- items collected so far
---@return lese.Item[]
function Picker:match_input(matcher, query, n)
  local previous = self.matched_query
  if
    not matcher.narrows
    or matcher.incremental
    or previous == nil
    or self.matched_count ~= n
    or not matcher.narrows(previous, query)
  then
    return copy_list(self.collected, n)
  end
  local kept = {}
  for _, item in ipairs(self.matched) do
    kept[item.id] = true
  end
  local items = {}
  for i = 1, n do
    local item = self.collected[i]
    if kept[item.id] then
      items[#items + 1] = item
    end
  end
  return items
end

-- While items are still arriving, matching again on every chunk would compete
-- with collecting and grow with the square of the items; a new match waits
-- twice as long as the last one took, and at least as long as fall waited.
local MATCH_COOLDOWN = 100

---Milliseconds on the editor's clock, which timers follow; the scheduler's
---clock counts processor time, which stands still while a source waits on a
---command. Without an editor the scheduler's clock is all there is.
---@return number
function Picker:wall()
  if self.host then
    return self.host.now()
  end
  return self.scheduler:now()
end

---Milliseconds left before a match that would only add arrived items may run.
---@return number
function Picker:cooldown_left()
  if not self.match_ended then
    return 0
  end
  local wait = math.max(MATCH_COOLDOWN, 2 * (self.match_cost or 0))
  return wait - (self:wall() - self.match_ended)
end

---True while a match that would only add arrived items should wait.
---@return boolean
function Picker:cooling()
  return self:cooldown_left() > 0
end

---Match the items that arrived during the cooldown once it is over, even when
---the source stays quiet until then.
function Picker:retry_match()
  if not self.host or self.retry_pending then
    return
  end
  self.retry_pending = true
  self.host.defer(math.max(1, math.ceil(self:cooldown_left())), function()
    self.retry_pending = false
    if self.match_dirty and not self.disposed then
      self:request_match(false)
    end
  end)
end

---Sort what was matched, then render it.
function Picker:request_sort()
  local sorter = self.sorters[self.sorter_index]
  local items = copy_list(self.matched)
  if not sorter then
    if self.tasks.sort then
      self.tasks.sort:cancel()
    end
    self:present(items)
    return
  end
  self:run("sort", sorter.name, function()
    sorter.sort(self:context_for(sorter.name), { items = items })
  end, {
    done = function()
      self:present(items)
    end,
    failed = function()
      self.processing = "failed"
      self:present(copy_list(self.matched))
    end,
  })
end

---Show `items` as the filtered list and render it.
function Picker:present(items)
  self.filtered = items
  if not self.tasks.match and self.processing ~= "failed" then
    self.processing = false
  end
  self:notify("status")
  self:request_render()
end

---Clamp the cursor and scroll so it stays in view.
function Picker:adjust()
  local count = #self.filtered
  if count == 0 then
    self.cursor = 0
    self.offset = 0
    return
  end
  self.cursor = clamp(self.cursor, 1, count)
  self.offset =
    M.adjust_offset(self.offset, self.cursor - 1, count, self.height, self.scroll_offset)
end

---Render the rows on screen.
function Picker:request_render()
  self:adjust()
  local rows = {}
  for i = self.offset + 1, math.min(self.offset + self.height, #self.filtered) do
    local item = self.filtered[i]
    local row = {}
    for k, v in pairs(item) do
      row[k] = v
    end
    row.label = item.label or item.value
    row.decorations = copy_list(item.decorations or {})
    rows[#rows + 1] = row
  end
  local renderer = self.renderers[self.renderer_index]
  local function done()
    self.visible = rows
    self:notify("render")
    local current = self:current_item()
    if current ~= self.previewed then
      self:notify("cursor")
    end
  end
  if not renderer then
    if self.tasks.render then
      self.tasks.render:cancel()
    end
    done()
    return
  end
  self:run("render", renderer.name, function()
    renderer.render(self:context_for(renderer.name), { items = rows })
  end, {
    done = done,
    failed = function()
      self.processing = "failed"
      self:notify("status")
    end,
  })
end

---Preview the item under the cursor.
function Picker:request_preview()
  local item = self:current_item()
  self.previewed = item
  local previewer = self.previewers[self.previewer_index]
  if not item or not previewer then
    if self.tasks.preview then
      self.tasks.preview:cancel()
    end
    self.preview = nil
    self:notify("preview")
    return
  end
  local result
  self:run("preview", previewer.name, function()
    result = previewer.preview(self:context_for(previewer.name), { item = item })
  end, {
    done = function()
      self.preview = result
      self:notify("preview")
    end,
    failed = function()
      self.preview = { content = { "Failed to preview the item. See :messages." } }
      self:notify("preview")
    end,
  })
end

---The item under the cursor, or nil when the list is empty.
---@return lese.Item?
function Picker:current_item()
  return self.filtered[self.cursor]
end

---The cursor's row within the visible rows, 1-based; 0 when empty.
---@return integer
function Picker:line()
  if self.cursor == 0 then
    return 0
  end
  return self.cursor - self.offset
end

---Change the query and match again.
---@param query string
function Picker:set_query(query)
  if query == self.query then
    return
  end
  self.query = query
  self:notify("query")
  self:request_match(true)
end

---Change how many rows the list shows (at least 1).
---@param height integer
function Picker:set_height(height)
  self.height = math.max(1, height)
  self:request_render()
end

---Move the cursor by `amount` rows, stopping at either end.
---@param amount integer
function Picker:move_cursor(amount)
  if #self.filtered == 0 then
    return
  end
  self.cursor = clamp(self.cursor + amount, 1, #self.filtered)
  self:request_render()
end

---@param index integer|"$"   -- 1-based; "$" is the last item
function Picker:move_cursor_at(index)
  self.cursor = index == "$" and #self.filtered or index --[[@as integer]]
  self:request_render()
end

---@alias lese.SelectMethod "on"|"off"|"toggle"

---Select the item at `index` (default: the cursor).
---@param index? integer|"$"
---@param method? lese.SelectMethod
function Picker:select(index, method)
  if index == "$" then
    index = #self.filtered
  end
  local item = self.filtered[index or self.cursor]
  if not item then
    return
  end
  method = method or "toggle"
  local id = item.id
  if method == "on" or (method == "toggle" and not self.selection[id]) then
    self.selection[id] = true
  else
    self.selection[id] = nil
  end
  self:notify("selection")
end

---@param method? lese.SelectMethod
function Picker:select_all(method)
  method = method or "toggle"
  if method == "off" then
    self.selection = {}
  else
    for _, item in ipairs(self.filtered) do
      local id = item.id
      if method == "on" or not self.selection[id] then
        self.selection[id] = true
      else
        self.selection[id] = nil
      end
    end
  end
  self:notify("selection")
end

local function step(index, amount, count, cycle)
  local next_index = index + amount
  if cycle then
    next_index = (next_index - 1) % count + 1
  end
  return clamp(next_index, 1, math.max(1, count))
end

local function at(index, count)
  if index == "$" then
    return math.max(1, count)
  end
  return clamp(index, 1, math.max(1, count))
end

---Switch the matcher by `amount` places, wrapping around when `cycle`.
---@param amount integer
---@param cycle? boolean
function Picker:switch_matcher(amount, cycle)
  self:switch_matcher_at(step(self.matcher_index, amount, #self.matchers, cycle))
end

---@param index integer|"$"
function Picker:switch_matcher_at(index)
  self.matcher_index = at(index, #self.matchers)
  self.matched_query = nil
  self:notify("indicator")
  self:request_match(true)
end

---Switch the sorter by `amount` places, wrapping around when `cycle`.
---@param amount integer
---@param cycle? boolean
function Picker:switch_sorter(amount, cycle)
  self:switch_sorter_at(step(self.sorter_index, amount, #self.sorters, cycle))
end

---@param index integer|"$"
function Picker:switch_sorter_at(index)
  self.sorter_index = at(index, #self.sorters)
  self:notify("indicator")
  self:request_sort()
end

---Switch the renderer by `amount` places, wrapping around when `cycle`.
---@param amount integer
---@param cycle? boolean
function Picker:switch_renderer(amount, cycle)
  self:switch_renderer_at(step(self.renderer_index, amount, #self.renderers, cycle))
end

---@param index integer|"$"
function Picker:switch_renderer_at(index)
  self.renderer_index = at(index, #self.renderers)
  self:notify("indicator")
  self:request_render()
end

---Switch the previewer by `amount` places, wrapping around when `cycle`.
---@param amount integer
---@param cycle? boolean
function Picker:switch_previewer(amount, cycle)
  self:switch_previewer_at(step(self.previewer_index, amount, #self.previewers, cycle))
end

---@param index integer|"$"
function Picker:switch_previewer_at(index)
  self.previewer_index = at(index, #self.previewers)
  self:notify("indicator")
  self:request_preview()
end

---The selected items in list order, or nil when nothing is selected.
---@return lese.Item[]?
function Picker:selected_items()
  if next(self.selection) == nil then
    return nil
  end
  local items = {}
  for _, item in ipairs(self.filtered) do
    if self.selection[item.id] then
      items[#items + 1] = item
    end
  end
  return items
end

---What an action receives.
---@return lese.InvokeParams
function Picker:result()
  return {
    query = self.query,
    item = self:current_item(),
    selected_items = self:selected_items(),
    filtered_items = self.filtered,
  }
end

---A snapshot to resume the picker from.
---@return lese.PickerContext
function Picker:snapshot()
  return {
    query = self.query,
    selection = self.selection,
    collected = self.collected,
    filtered = self.filtered,
    cursor = self.cursor,
    offset = self.offset,
    matcher_index = self.matcher_index,
    sorter_index = self.sorter_index,
    renderer_index = self.renderer_index,
    previewer_index = self.previewer_index,
  }
end

---Cancel every stage.
function Picker:dispose()
  self.disposed = true
  for _, task in pairs(self.tasks) do
    task:cancel()
  end
  self.tasks = {}
end

return M
