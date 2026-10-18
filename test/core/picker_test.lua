local t = require("lese.testing")
local define = require("lese.define")
local scheduler_mod = require("lese.core.scheduler")
local picker_mod = require("lese.core.picker")

local function list_source(values)
  return define.source({
    name = "test.list",
    collect = function(ctx)
      for i, value in ipairs(values) do
        ctx:emit({ id = i, value = value, detail = {} })
        ctx:checkpoint()
      end
    end,
  })
end

local function contains(name)
  return define.matcher({
    name = name or "test.contains",
    match = function(ctx, params)
      for _, item in ipairs(params.items) do
        if string.find(item.value, params.query, 1, true) then
          ctx:emit(item)
        end
        ctx:checkpoint()
      end
    end,
  })
end

local reverse = define.sorter({
  name = "test.reverse",
  sort = function(_, params)
    table.sort(params.items, function(a, b)
      return a.value > b.value
    end)
  end,
})

local upper = define.renderer({
  name = "test.upper",
  render = function(_, params)
    for _, item in ipairs(params.items) do
      item.label = string.upper(item.value)
    end
  end,
})

local function new(params)
  local notifications = {}
  local errors = {}
  local s = scheduler_mod.new()
  params.name = params.name or "test"
  params.scheduler = s
  params.matchers = params.matchers or { contains() }
  params.on_update = function(kind)
    notifications[#notifications + 1] = kind
  end
  params.on_error = function(stage, message)
    errors[#errors + 1] = { stage, message }
  end
  local picker = picker_mod.new(params)
  return picker, s, notifications, errors
end

local function labels(picker)
  local out = {}
  for i, item in ipairs(picker.visible) do
    out[i] = item.label
  end
  return out
end

t.describe("picker", function()
  t.it("collects, matches and renders the items of the source", function()
    local picker, s = new({ source = list_source({ "apple", "banana", "cherry" }) })
    picker:start()
    s:drain()
    t.eq(t.values(picker.collected), { "apple", "banana", "cherry" })
    t.eq(labels(picker), { "apple", "banana", "cherry" })
    t.eq(picker.collecting, false)
    t.eq(picker.processing, false)
  end)

  t.it("narrows the list by the query", function()
    local picker, s = new({ source = list_source({ "apple", "banana", "cherry" }) })
    picker:start()
    s:drain()
    picker:set_query("an")
    s:drain()
    t.eq(labels(picker), { "banana" })
  end)

  t.it("restarts a match in progress when the query changes", function()
    local picker, s = new({ source = list_source({ "apple", "banana" }) })
    picker:start()
    s:drain()
    picker:set_query("a")
    picker:set_query("ap")
    s:drain()
    t.eq(labels(picker), { "apple" })
  end)

  t.it("sorts with the current sorter and renders with the current renderer", function()
    local picker, s = new({
      source = list_source({ "apple", "banana", "cherry" }),
      sorters = { reverse },
      renderers = { upper },
    })
    picker:start()
    s:drain()
    t.eq(labels(picker), { "CHERRY", "BANANA", "APPLE" })
  end)

  t.it("does not change the items it hands to renderers", function()
    local picker, s = new({ source = list_source({ "apple" }), renderers = { upper } })
    picker:start()
    s:drain()
    t.eq(picker.filtered[1].label, nil)
  end)

  t.it("switches to the next sorter and back", function()
    local noop = define.sorter({ name = "test.noop", sort = function() end })
    local picker, s = new({
      source = list_source({ "a", "c", "b" }),
      sorters = { noop, reverse },
    })
    picker:start()
    s:drain()
    t.eq(labels(picker), { "a", "c", "b" })
    picker:switch_sorter(1, true)
    s:drain()
    t.eq(labels(picker), { "c", "b", "a" })
    picker:switch_sorter(1, true)
    s:drain()
    t.eq(picker.sorter_index, 1)
  end)

  t.it("switches matchers and matches again with the same query", function()
    local none = define.matcher({ name = "test.none", match = function() end })
    local picker, s = new({ source = list_source({ "a", "b" }), matchers = { contains(), none } })
    picker:start()
    s:drain()
    picker:switch_matcher_at("$")
    s:drain()
    t.eq(labels(picker), {})
    t.eq(picker.cursor, 0)
  end)

  t.it("moves the cursor within the list and scrolls to keep it in view", function()
    local values = {}
    for i = 1, 20 do
      values[i] = string.format("%02d", i)
    end
    local picker, s = new({ source = list_source(values), height = 5, scroll_offset = 1 })
    picker:start()
    s:drain()
    t.eq(picker.cursor, 1)
    picker:move_cursor(4)
    s:drain()
    t.eq(picker.cursor, 5)
    t.eq(picker.offset, 1)
    t.eq(labels(picker), { "02", "03", "04", "05", "06" })
    picker:move_cursor_at("$")
    s:drain()
    t.eq(picker.cursor, 20)
    t.eq(picker:line(), 5)
    picker:move_cursor(100)
    t.eq(picker.cursor, 20)
    picker:move_cursor(-100)
    s:drain()
    t.eq(picker.cursor, 1)
    t.eq(picker.offset, 0)
  end)

  t.it("selects items by id and returns them in list order", function()
    local picker, s = new({ source = list_source({ "a", "b", "c" }) })
    picker:start()
    s:drain()
    picker:select(3)
    picker:select(1)
    t.eq(t.values(picker:selected_items()), { "a", "c" })
    picker:select(1)
    t.eq(t.values(picker:selected_items()), { "c" })
    picker:select_all("off")
    t.eq(picker:selected_items(), nil)
    picker:select_all()
    t.eq(#picker:selected_items(), 3)
  end)

  t.it("hands the cursor item, the selection and the filtered items to actions", function()
    local picker, s = new({ source = list_source({ "a", "ab", "b" }) })
    picker:start()
    s:drain()
    picker:set_query("a")
    s:drain()
    picker:move_cursor(1)
    s:drain()
    local result = picker:result()
    t.eq(result.query, "a")
    t.eq(result.item.value, "ab")
    t.eq(result.selected_items, nil)
    t.eq(t.values(result.filtered_items), { "a", "ab" })
  end)

  t.it("previews the item under the cursor", function()
    local previewer = define.previewer({
      name = "test.previewer",
      preview = function(_, params)
        return { content = { "preview of " .. params.item.value } }
      end,
    })
    local picker, s = new({ source = list_source({ "a" }), previewers = { previewer } })
    picker:start()
    s:drain()
    picker:request_preview()
    s:drain()
    t.eq(picker.preview, { content = { "preview of a" } })
  end)

  t.it("waits between matches while items are still arriving, then matches them all", function()
    local now = 0
    local s = scheduler_mod.new({
      budget = 1,
      clock = function()
        return now
      end,
    })
    local runs = 0
    local counting = define.matcher({
      name = "test.counting",
      match = function(ctx, params)
        runs = runs + 1
        for _, item in ipairs(params.items) do
          ctx:emit(item)
        end
      end,
    })
    local source = define.source({
      name = "test.slow",
      collect = function(ctx)
        for i = 1, 200 do
          ctx:emit({ id = i, value = tostring(i), detail = {} })
          now = now + 1
          ctx:checkpoint()
        end
      end,
    })
    local picker = picker_mod.new({
      name = "test",
      source = source,
      matchers = { counting },
      scheduler = s,
    })
    picker:start()
    s:drain()
    t.eq(#picker.filtered, 200)
    t.ok(runs <= 4, "matched " .. runs .. " times for 200 chunks")
  end)

  t.it("matches what arrived during the cooldown while the source waits", function()
    local wall, timers = 0, {}
    local host = {
      now = function()
        return wall
      end,
      defer = function(ms, callback)
        timers[#timers + 1] = { at = wall + ms, callback = callback }
      end,
    }
    local release
    local source = define.source({
      name = "test.waiting",
      collect = function(ctx)
        ctx:emit({ id = 1, value = "a", detail = {} })
        ctx:await(function(resolve)
          release = resolve
        end)
      end,
    })
    local s = scheduler_mod.new()
    local picker = picker_mod.new({
      name = "test",
      source = source,
      matchers = { contains() },
      scheduler = s,
      host = host,
    })
    picker:start()
    s:drain()
    t.eq(#picker.filtered, 1)
    picker.collected[2] = { id = 2, value = "b", detail = {} }
    picker:request_match(false)
    s:drain()
    t.eq(#picker.filtered, 1)
    wall = wall + 1000
    for _, timer in ipairs(timers) do
      if timer.at <= wall then
        timer.callback()
      end
    end
    s:drain()
    t.eq(#picker.filtered, 2)
    release()
    s:drain()
  end)

  t.it("stops collecting at the threshold and says the list is truncated", function()
    local picker, s = new({ source = list_source({ "a", "b", "c" }), threshold = 2 })
    picker:start()
    s:drain()
    t.eq(t.values(picker.collected), { "a", "b" })
    t.eq(picker.truncated, true)
    t.eq(picker.collecting, false)
  end)

  t.it("reports a failing source and marks collecting as failed", function()
    local broken = define.source({
      name = "test.broken",
      collect = function()
        error("no luck")
      end,
    })
    local picker, s, _, errors = new({ source = broken })
    picker:start()
    s:drain()
    t.eq(picker.collecting, "failed")
    t.eq(errors[1][1], "collect")
    t.ok(string.find(errors[1][2], "no luck", 1, true))
  end)

  t.it("resumes from a snapshot without collecting again", function()
    local picker, s = new({ source = list_source({ "a", "ab", "b" }) })
    picker:start()
    s:drain()
    picker:set_query("a")
    s:drain()
    picker:move_cursor(1)
    picker:select(1)
    s:drain()
    local snapshot = picker:snapshot()
    local never = define.source({
      name = "test.never",
      collect = function()
        error("collected again")
      end,
    })
    local resumed, s2 = new({ source = never, context = snapshot })
    resumed:start()
    s2:drain()
    t.eq(resumed.query, "a")
    t.eq(resumed.cursor, 2)
    t.eq(labels(resumed), { "a", "ab" })
    t.eq(t.values(resumed:selected_items()), { "a" })
  end)
end)

t.describe("adjust_offset", function()
  t.it("keeps everything in view when the list fits", function()
    t.eq(picker_mod.adjust_offset(3, 4, 5, 10, 2), 0)
  end)

  t.it("scrolls down to keep the margin below the cursor", function()
    t.eq(picker_mod.adjust_offset(0, 8, 20, 10, 2), 1)
  end)

  t.it("scrolls up to keep the margin above the cursor", function()
    t.eq(picker_mod.adjust_offset(5, 6, 20, 10, 2), 4)
  end)

  t.it("never scrolls past either end", function()
    t.eq(picker_mod.adjust_offset(0, 19, 20, 10, 2), 10)
    t.eq(picker_mod.adjust_offset(10, 0, 20, 10, 2), 0)
  end)
end)
