local t = require("lese.testing")
local define = require("lese.define")
local std = require("lese.std")

local function source_of(name, values)
  return define.source({
    name = name,
    collect = function(ctx, params)
      for _, value in ipairs(values) do
        ctx:emit(t.item(value, { args = params.args }))
      end
    end,
  })
end

local function curator_of(name, values)
  return define.curator({
    name = name,
    curate = function(ctx, params)
      for _, value in ipairs(values) do
        ctx:emit(t.item(value .. ":" .. params.query, { args = params.args }))
      end
    end,
  })
end

local function refiner_of(name, fn)
  return define.refiner({
    name = name,
    refine = function(_, item)
      return fn(item)
    end,
  })
end

local function with_suffix(suffix)
  return refiner_of("suffix" .. suffix, function(item)
    return t.item(item.value .. suffix, item.detail)
  end)
end

local function matcher_keeping(name, letter)
  return define.matcher({
    name = name,
    match = function(ctx, params)
      local kept = {}
      for _, item in ipairs(params.items) do
        if string.find(item.value, letter, 1, true) then
          kept[#kept + 1] = item
        end
      end
      ctx:emit(kept)
    end,
  })
end

t.describe("std.refine_source", function()
  t.it("passes each item through the refiners in order", function()
    local source =
      std.refine_source(source_of("s", { "a", "b" }), with_suffix("1"), with_suffix("2"))
    t.eq(t.values(t.collect(source)), { "a12", "b12" })
  end)

  t.it("drops an item a refiner returns nil for", function()
    local drop_b = refiner_of("drop_b", function(item)
      if item.value ~= "b" then
        return item
      end
    end)
    local source = std.refine_source(source_of("s", { "a", "b", "c" }), drop_b, with_suffix("!"))
    t.eq(t.values(t.collect(source)), { "a!", "c!" })
  end)

  t.it("is named after the source", function()
    t.eq(std.refine_source(source_of("my.source", {}), with_suffix("1")).name, "refine(my.source)")
  end)

  t.it("passes the arguments to the source", function()
    local items = t.collect(std.refine_source(source_of("s", { "a" })), { args = { "x" } })
    t.eq(items[1].detail.args, { "x" })
  end)
end)

t.describe("std.refine_curator", function()
  t.it("passes each item through the refiners in order", function()
    local curator = std.refine_curator(curator_of("c", { "a" }), with_suffix("1"))
    t.eq(t.values(t.curate(curator, { query = "q" })), { "a:q1" })
    t.eq(curator.name, "refine(c)")
  end)
end)

t.describe("std.bind_source_args", function()
  t.it("puts the bound arguments before the given ones", function()
    local source = std.bind_source_args(source_of("s", { "a" }), { "x", "y" })
    t.eq(t.collect(source, { args = { "z" } })[1].detail.args, { "x", "y", "z" })
    t.eq(source.name, "bind(s)")
  end)

  t.it("takes the arguments from a function called with the context", function()
    local source = std.bind_source_args(source_of("s", { "a" }), function(ctx)
      return { ctx.name }
    end)
    t.eq(t.collect(source)[1].detail.args, { "bind(s)" })
  end)
end)

t.describe("std.bind_curator_args", function()
  t.it("puts the bound arguments before the given ones and keeps the query", function()
    local curator = std.bind_curator_args(curator_of("c", { "a" }), { "x" })
    local items = t.curate(curator, { args = { "z" }, query = "q" })
    t.eq(t.values(items), { "a:q" })
    t.eq(items[1].detail.args, { "x", "z" })
  end)
end)

t.describe("std.compose_sources", function()
  t.it("emits the items of every source in turn with fresh ids", function()
    local source = std.compose_sources(source_of("s1", { "a", "b" }), source_of("s2", { "a" }))
    local items = t.collect(source)
    t.eq(t.values(items), { "a", "b", "a" })
    t.eq({ items[1].id, items[2].id, items[3].id }, { 1, 2, 3 })
    t.eq(source.name, "compose(s1, s2)")
  end)

  t.it("requires a source", function()
    t.raises(function()
      std.compose_sources()
    end, "std.compose_sources() needs at least one source")
  end)
end)

t.describe("std.compose_curators", function()
  t.it("emits the items of every curator in turn with fresh ids", function()
    local curator = std.compose_curators(curator_of("c1", { "a" }), curator_of("c2", { "b" }))
    local items = t.curate(curator, { query = "q" })
    t.eq(t.values(items), { "a:q", "b:q" })
    t.eq({ items[1].id, items[2].id }, { 1, 2 })
  end)
end)

t.describe("std.compose_matchers", function()
  t.it("passes the items through each matcher in turn", function()
    local matcher = std.compose_matchers(matcher_keeping("m1", "a"), matcher_keeping("m2", "b"))
    local items = t.match(matcher, { query = "", items = t.items({ "ab", "a", "b", "ba" }) })
    t.eq(t.values(items), { "ab", "ba" })
    t.eq(matcher.name, "compose(m1, m2)")
  end)
end)

t.describe("std.compose_sorters", function()
  t.it("runs every sorter in turn", function()
    local reverse = define.sorter({
      name = "reverse",
      sort = function(_, params)
        local items, n = params.items, #params.items
        for i = 1, math.floor(n / 2) do
          items[i], items[n - i + 1] = items[n - i + 1], items[i]
        end
      end,
    })
    local sorter = std.compose_sorters(reverse, reverse, reverse)
    t.eq(t.values(t.sort(sorter, t.items({ "a", "b", "c" }))), { "c", "b", "a" })
  end)
end)

t.describe("std.compose_renderers", function()
  t.it("runs every renderer in turn", function()
    local function wrap(name, left, right)
      return define.renderer({
        name = name,
        render = function(_, params)
          for _, item in ipairs(params.items) do
            item.label = left .. item.label .. right
          end
        end,
      })
    end
    local renderer = std.compose_renderers(wrap("r1", "(", ")"), wrap("r2", "[", "]"))
    t.eq(t.render(renderer, t.items({ "a" }))[1].label, "[(a)]")
  end)
end)

t.describe("std.compose_previewers", function()
  t.it("returns the first preview that is not nil", function()
    local none = define.previewer({
      name = "none",
      preview = function() end,
    })
    local function content(name, line)
      return define.previewer({
        name = name,
        preview = function()
          return { content = { line } }
        end,
      })
    end
    local previewer = std.compose_previewers(none, content("p1", "one"), content("p2", "two"))
    t.eq(t.preview(previewer, t.item("a")), { content = { "one" } })
  end)

  t.it("returns nil when every previewer does", function()
    local none = define.previewer({ name = "none", preview = function() end })
    t.eq(t.preview(std.compose_previewers(none), t.item("a")), nil)
  end)
end)

t.describe("std.compose_actions", function()
  local function action_of(name, calls, keep)
    return define.action({
      name = name,
      invoke = function()
        calls[#calls + 1] = name
        return keep
      end,
    })
  end

  t.it("invokes every action in order", function()
    local calls = {}
    local keep = t.invoke(std.compose_actions(action_of("a1", calls), action_of("a2", calls)), {})
    t.eq(calls, { "a1", "a2" })
    t.ok(not keep)
  end)

  t.it("keeps the picker open when any action asks to", function()
    local calls = {}
    local action = std.compose_actions(action_of("a1", calls, true), action_of("a2", calls))
    t.eq(t.invoke(action, {}), true)
  end)
end)
