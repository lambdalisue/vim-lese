-- The test API for lese and its extensions. The same tests run on Neovim and
-- on Vim (+lua): start them with lese.testing.runner.

local runner = require("lese.testing.runner")
local inspect = require("lese.testing.inspect")
local contract = require("lese.core.contract")
local scheduler_mod = require("lese.core.scheduler")
local context = require("lese.core.context")

local M = {}

M.describe = runner.describe
M.it = runner.it
M.inspect = inspect

local function deep_equal(a, b)
  if type(a) ~= type(b) then
    return false
  end
  if type(a) ~= "table" then
    return a == b
  end
  for k, v in pairs(a) do
    if not deep_equal(v, b[k]) then
      return false
    end
  end
  for k in pairs(b) do
    if a[k] == nil then
      return false
    end
  end
  return true
end

local function fail(message, level)
  -- selene: allow(incorrect_standard_library_use)
  error({ message = message .. "\n" .. debug.traceback("", level + 1) }, level + 1)
end

---Assert that two values are equal, comparing tables by content.
---@param actual any
---@param expected any
---@param message? string
function M.eq(actual, expected, message)
  if not deep_equal(actual, expected) then
    fail(
      (message and message .. "\n" or "")
        .. "expected: "
        .. inspect(expected)
        .. "\n  actual: "
        .. inspect(actual),
      2
    )
  end
end

---Assert that a value is truthy.
---@param value any
---@param message? string
function M.ok(value, message)
  if not value then
    fail(message or ("expected a truthy value, got " .. inspect(value)), 2)
  end
end

---Assert that `fn` raises an error, whose message contains `text` when given.
---@param fn fun()
---@param text? string
---@return string message
function M.raises(fn, text)
  local ok, err = pcall(fn)
  if ok then
    fail("expected an error, but none was raised", 2)
  end
  local message = type(err) == "table" and (err.message or inspect(err)) or tostring(err)
  if text and not string.find(message, text, 1, true) then
    fail("expected an error containing " .. inspect(text) .. ", got " .. inspect(message), 2)
  end
  return message
end

-- Tests check every contract.
contract.strict = true

---The host when running inside an editor, nil in a bare Lua.
---@return lese.Host?
local function current_host()
  if require("lese.core.compat").in_editor() then
    return require("lese.host")
  end
  return nil
end

---@class lese.TestRunOptions
---@field timeout? integer  -- milliseconds to wait for the module, default 10000

---Run `fn(ctx)` as a module would run, with a context whose emitted items are
---returned, and wait for it to finish (external commands included).
---@param name string
---@param fn fun(ctx: lese.Context): any
---@param opts? lese.TestRunOptions
---@return lese.Item[] emitted
---@return any result what `fn` returned
function M.run(name, fn, opts)
  opts = opts or {}
  local host = current_host()
  local s = scheduler_mod.new({
    on_starve = function(task, elapsed)
      contract.warn(
        string.format("lese: %s ran %d ms without ctx:checkpoint()", task.name, elapsed)
      )
    end,
  })
  local emitted = {}
  local ctx = context.new({
    scheduler = s,
    host = host,
    name = name,
    sink = function(items)
      for _, item in ipairs(items) do
        emitted[#emitted + 1] = item
      end
    end,
  })
  local result
  local task = s:spawn(function()
    result = fn(ctx)
  end, { name = name })
  local deadline = os.time() + math.ceil((opts.timeout or 10000) / 1000)
  while true do
    s:drain()
    if task:finished() then
      break
    end
    if not host then
      error(name .. " waits on the editor, which a bare Lua does not have", 2)
    end
    if os.time() > deadline then
      task:cancel()
      error(name .. " did not finish in time", 2)
    end
    host.wait(10, function()
      return not task:finished() and task.status == "ready"
    end)
  end
  if task.status == "failed" then
    error(task.traceback or tostring(task.error), 0)
  end
  return emitted, result
end

---Build an item with `value` as its value and id.
---@param value string
---@param detail? table
---@return lese.Item
function M.item(value, detail)
  return { id = value, value = value, detail = detail or {} }
end

---Build items from values.
---@param values string[]
---@return lese.Item[]
function M.items(values)
  local items = {}
  for i, value in ipairs(values) do
    items[i] = M.item(value)
  end
  return items
end

---The values of items, in order.
---@param items lese.Item[]
---@return string[]
function M.values(items)
  local values = {}
  for i, item in ipairs(items) do
    values[i] = item.value
  end
  return values
end

---Collect every item a source emits.
---@param source lese.Source
---@param params? { args?: string[] }
---@return lese.Item[]
function M.collect(source, params)
  params = params or {}
  return (
    M.run(source.name, function(ctx)
      source.collect(ctx, { args = params.args or {} })
    end)
  )
end

---Collect every item a curator emits for a query.
---@param curator lese.Curator
---@param params { args?: string[], query: string }
---@return lese.Item[]
function M.curate(curator, params)
  return (
    M.run(curator.name, function(ctx)
      curator.curate(ctx, { args = params.args or {}, query = params.query })
    end)
  )
end

---Match items against a query.
---@param matcher lese.Matcher
---@param params { query: string, items: lese.Item[] }
---@return lese.Item[]
function M.match(matcher, params)
  return (
    M.run(matcher.name, function(ctx)
      matcher.match(ctx, { query = params.query, items = params.items })
    end)
  )
end

---Sort a copy of the items.
---@param sorter lese.Sorter
---@param items lese.Item[]
---@return lese.Item[]
function M.sort(sorter, items)
  local copy = {}
  for i, item in ipairs(items) do
    copy[i] = item
  end
  M.run(sorter.name, function(ctx)
    sorter.sort(ctx, { items = copy })
  end)
  return copy
end

---Render copies of the items, starting from `label = value` as the picker does.
---@param renderer lese.Renderer
---@param items lese.Item[]
---@return lese.Item[]
function M.render(renderer, items)
  local copy = {}
  for i, item in ipairs(items) do
    local c = {}
    for k, v in pairs(item) do
      c[k] = v
    end
    c.label = item.label or item.value
    c.decorations = item.decorations or {}
    copy[i] = c
  end
  M.run(renderer.name, function(ctx)
    renderer.render(ctx, { items = copy })
  end)
  return copy
end

---Preview an item.
---@param previewer lese.Previewer
---@param item lese.Item
---@return lese.PreviewItem?
function M.preview(previewer, item)
  local _, result = M.run(previewer.name, function(ctx)
    return previewer.preview(ctx, { item = item })
  end)
  return result
end

---Invoke an action.
---@param action lese.Action
---@param params { item?: lese.Item, selected_items?: lese.Item[], filtered_items?: lese.Item[], query?: string }
---@return boolean? keep true when the action keeps the picker open
function M.invoke(action, params)
  local _, result = M.run(action.name, function(ctx)
    return action.invoke(ctx, {
      item = params.item,
      selected_items = params.selected_items,
      filtered_items = params.filtered_items or {},
      query = params.query or "",
    })
  end)
  return result
end

---Refine one item.
---@param refiner lese.Refiner
---@param item lese.Item
---@return lese.Item?
function M.refine(refiner, item)
  local _, result = M.run(refiner.name, function(ctx)
    return refiner.refine(ctx, item)
  end)
  return result
end

return M
