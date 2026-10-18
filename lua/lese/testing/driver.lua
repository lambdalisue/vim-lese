-- Drive a picker without windows or keys: type a query, press picker keys, and
-- read what it would show. The same driver backs t.picker() and lese-run.

local compat = require("lese.core.compat")
local contract = require("lese.core.contract")
local scheduler_mod = require("lese.core.scheduler")
local context = require("lese.core.context")
local picker_mod = require("lese.core.picker")
local screen = require("lese.testing.screen")

local M = {}

---@class lese.DriverParams
---@field name? string
---@field source lese.Source
---@field matchers? lese.Matcher[]       -- default: a plain substring match
---@field sorters? lese.Sorter[]
---@field renderers? lese.Renderer[]
---@field previewers? lese.Previewer[]
---@field actions? table<string, lese.Action>
---@field default_action? string
---@field args? string[]
---@field height? integer                -- rows on screen, default 10
---@field query? string
---@field timeout? integer               -- milliseconds to wait for the pipeline, default 10000

---@class lese.Driver
---@field model lese.PickerModel
---@field errors string[]                -- what failed, by stage
---@field package scheduler lese.Scheduler
---@field package host? lese.Host
---@field package params lese.DriverParams
local Driver = {}
Driver.__index = Driver

local function substring()
  return require("lese.define").matcher({
    name = "lese.testing.substring",
    match = function(ctx, params)
      local query = params.query
      for _, item in ipairs(params.items) do
        if query == "" then
          ctx:emit(item)
        else
          local s = string.find(item.value, query, 1, true)
          if s then
            ctx:emit({
              id = item.id,
              value = item.value,
              detail = item.detail,
              label = item.label,
              decorations = { { column = s, length = #query } },
            })
          end
        end
        ctx:checkpoint()
      end
    end,
  })
end

---@param params lese.DriverParams
---@return lese.Driver
function M.new(params)
  local host = compat.in_editor() and require("lese.host") or nil
  local self = setmetatable({ params = params, errors = {}, host = host }, Driver)
  self.scheduler = scheduler_mod.new({
    on_starve = function(task, elapsed)
      contract.warn(
        string.format("lese: %s ran %d ms without ctx:checkpoint()", task.name, math.floor(elapsed))
      )
    end,
  })
  self.model = picker_mod.new({
    name = params.name or "test",
    source = params.source,
    matchers = params.matchers or { substring() },
    sorters = params.sorters,
    renderers = params.renderers,
    previewers = params.previewers,
    args = params.args,
    height = params.height or 10,
    scheduler = self.scheduler,
    host = host,
    on_error = function(stage, message)
      self.errors[#self.errors + 1] = stage .. ": " .. message
    end,
  })
  if params.query then
    self.model.query = params.query
  end
  self.model:start()
  self:wait()
  return self
end

---Wait until every stage finished, external commands included.
---@return lese.Driver
function Driver:wait()
  local s = self.scheduler
  local settled = require("lese.testing").settle(s, function()
    return not s:busy()
  end, self.params.timeout)
  if not settled then
    local running = self:running()
    self.model:dispose()
    s:drain()
    error("the picker did not settle in time; still running: " .. running, 2)
  end
  return self
end

function Driver:running()
  return self.model:running()
end

---Raise the first error a stage reported.
---@return lese.Driver
function Driver:check()
  if #self.errors > 0 then
    error(self.errors[1], 2)
  end
  return self
end

---Append `text` to the query, as typing it would.
---@param text string
---@return lese.Driver
function Driver:type(text)
  self.model:set_query(self.model.query .. text)
  return self:wait()
end

---Replace the query.
---@param query string
---@return lese.Driver
function Driver:query(query)
  self.model:set_query(query)
  return self:wait()
end

-- What lese's default keys do, by key.
local KEYS = {
  ["<C-n>"] = function(m)
    m:move_cursor(1)
  end,
  ["<C-p>"] = function(m)
    m:move_cursor(-1)
  end,
  ["<C-t>"] = function(m)
    m:move_cursor_at(1)
  end,
  ["<C-g>"] = function(m)
    m:move_cursor_at("$")
  end,
  ["<C-d>"] = function(m)
    m:move_cursor(math.max(1, math.floor(m.height / 2)))
  end,
  ["<C-u>"] = function(m)
    m:move_cursor(-math.max(1, math.floor(m.height / 2)))
  end,
  ["<C-,>"] = function(m)
    m:select()
  end,
  ["<C-.>"] = function(m)
    m:select_all()
  end,
  ["<C-j>"] = function(m)
    m:select()
    m:move_cursor(1)
  end,
  ["<C-k>"] = function(m)
    m:move_cursor(-1)
    m:select()
  end,
  ["<F2>"] = function(m)
    m:switch_matcher(1, true)
  end,
  ["<F3>"] = function(m)
    m:switch_sorter(1, true)
  end,
  ["<F4>"] = function(m)
    m:switch_renderer(1, true)
  end,
  ["<F5>"] = function(m)
    m:switch_previewer(1, true)
  end,
  ["<BS>"] = function(m)
    local chars = {}
    for ch in string.gmatch(m.query, "[%z\1-\127\194-\244][\128-\191]*") do
      chars[#chars + 1] = ch
    end
    chars[#chars] = nil
    m:set_query(table.concat(chars))
  end,
}

---Press a key as lese's default mappings define it: <C-n>, <C-p>, <C-t>,
---<C-g>, <C-d>, <C-u>, <C-,>, <C-.>, <C-j>, <C-k>, <F2>–<F5>, <BS>.
---@param key string
---@return lese.Driver
function Driver:press(key)
  local fn = KEYS[key]
  if not fn then
    local known = {}
    for k in pairs(KEYS) do
      known[#known + 1] = k
    end
    table.sort(known)
    error(string.format("unknown key %s; known keys are %s", key, table.concat(known, " ")), 2)
  end
  fn(self.model)
  return self:wait()
end

---The picker as text: a header line, then one line per row on screen.
---@return string
function Driver:screen()
  return table.concat(screen.lines(self.model), "\n")
end

---Every item the matcher let through, in list order.
---@return lese.Item[]
function Driver:items()
  return self.model.filtered
end

---Preview the item under the cursor.
---@return lese.PreviewItem?
function Driver:preview()
  self.model:request_preview()
  self:wait()
  return self.model.preview
end

---What an action would receive now.
---@return lese.InvokeParams
function Driver:result()
  return self.model:result()
end

---Invoke the action `name` (default: `default_action`) as accepting the picker
---would, and return whether it keeps the picker open.
---@param name? string
---@return boolean? keep
function Driver:invoke(name)
  local actions = self.params.actions or {}
  name = name or self.params.default_action
  local action = name and actions[name]
  if not action then
    error(string.format("no action '%s' to invoke", tostring(name)), 2)
  end
  local s = self.scheduler
  local result
  local task = s:spawn(function()
    result = action.invoke(
      context.new({ scheduler = s, host = self.host, name = name }),
      self.model:result()
    )
  end, { name = name })
  local done = require("lese.testing").settle(s, function()
    return task:finished()
  end, self.params.timeout)
  if not done then
    task:cancel()
    s:drain()
    error(string.format("action '%s' did not finish in time", name), 2)
  end
  if task.status == "failed" then
    error(task.traceback or tostring(task.error), 0)
  end
  return result
end

---Stop the work in progress.
function Driver:close()
  self.model:dispose()
end

return M
