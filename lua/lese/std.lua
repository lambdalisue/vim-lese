-- Build modules out of other modules: refine a source's items, bind its
-- arguments, or chain several modules of one kind into one. Every result is
-- made with lese.define, so it is checked and named like any other module.

local define = require("lese.define")

local M = {}

---@param fn_name string
---@param kind string
---@param modules { name: string }[]
---@return string
local function compose_name(fn_name, kind, modules)
  if #modules == 0 then
    error(string.format("lese: std.%s() needs at least one %s", fn_name, kind), 3)
  end
  local names = {}
  for i, module in ipairs(modules) do
    names[i] = module.name
  end
  return "compose(" .. table.concat(names, ", ") .. ")"
end

---A context whose emitted items go through `transform` (one list at a time)
---before they reach `ctx`.
---@param ctx lese.Context
---@param transform fun(items: lese.Item[]): lese.Item[]
---@return lese.Context
local function piped(ctx, transform)
  return ctx:derive({
    sink = function(items)
      ctx:emit(transform(items))
    end,
  })
end

---@param ctx lese.Context
---@param refiners lese.Refiner[]
---@return fun(items: lese.Item[]): lese.Item[]
local function refining(ctx, refiners)
  return function(items)
    local out = {}
    for i, item in ipairs(items) do
      if i % 64 == 0 then
        ctx:checkpoint()
      end
      local refined = item ---@type lese.Item?
      for _, refiner in ipairs(refiners) do
        refined = refiner.refine(ctx, refined --[[@as lese.Item]])
        if refined == nil then
          break
        end
      end
      if refined ~= nil then
        out[#out + 1] = refined
      end
    end
    return out
  end
end

---@return fun(items: lese.Item[]): lese.Item[]
local function renumbering()
  local id = 0
  return function(items)
    local out = {}
    for i, item in ipairs(items) do
      local copy = {}
      for k, v in pairs(item) do
        copy[k] = v
      end
      id = id + 1
      copy.id = id
      out[i] = copy
    end
    return out
  end
end

---@param bound string[]
---@param given string[]
---@return string[]
local function concat_args(bound, given)
  local args = {}
  for _, arg in ipairs(bound) do
    args[#args + 1] = arg
  end
  for _, arg in ipairs(given) do
    args[#args + 1] = arg
  end
  return args
end

---@alias lese.std.BoundArgs string[]|fun(ctx: lese.Context): string[]

---@param ctx lese.Context
---@param args lese.std.BoundArgs
---@return string[]
local function resolve_args(ctx, args)
  if type(args) == "function" then
    return args(ctx)
  end
  return args
end

---A source whose items pass through the refiners in order; an item a refiner
---returns nil for is dropped.
---@param source lese.Source
---@param ... lese.Refiner
---@return lese.Source
function M.refine_source(source, ...)
  local refiners = { ... }
  return define.source({
    name = "refine(" .. source.name .. ")",
    collect = function(ctx, params)
      source.collect(piped(ctx, refining(ctx, refiners)), params)
    end,
  })
end

---A curator whose items pass through the refiners in order; an item a
---refiner returns nil for is dropped.
---@param curator lese.Curator
---@param ... lese.Refiner
---@return lese.Curator
function M.refine_curator(curator, ...)
  local refiners = { ... }
  return define.curator({
    name = "refine(" .. curator.name .. ")",
    curate = function(ctx, params)
      curator.curate(piped(ctx, refining(ctx, refiners)), params)
    end,
  })
end

---A source that gets `args` before the arguments the picker passes. `args`
---may be a function, called with the context on every run.
---@param source lese.Source
---@param args lese.std.BoundArgs
---@return lese.Source
function M.bind_source_args(source, args)
  return define.source({
    name = "bind(" .. source.name .. ")",
    collect = function(ctx, params)
      source.collect(ctx, { args = concat_args(resolve_args(ctx, args), params.args) })
    end,
  })
end

---A curator that gets `args` before the arguments the picker passes. `args`
---may be a function, called with the context on every run.
---@param curator lese.Curator
---@param args lese.std.BoundArgs
---@return lese.Curator
function M.bind_curator_args(curator, args)
  return define.curator({
    name = "bind(" .. curator.name .. ")",
    curate = function(ctx, params)
      curator.curate(ctx, {
        args = concat_args(resolve_args(ctx, args), params.args),
        query = params.query,
      })
    end,
  })
end

---A source that emits the items of every source in turn. Items get new ids
---(1, 2, ...) because ids are unique only within each source.
---@param ... lese.Source
---@return lese.Source
function M.compose_sources(...)
  local sources = { ... }
  return define.source({
    name = compose_name("compose_sources", "source", sources),
    collect = function(ctx, params)
      local out = piped(ctx, renumbering())
      for _, source in ipairs(sources) do
        source.collect(out, params)
      end
    end,
  })
end

---A curator that emits the items of every curator in turn. Items get new ids
---(1, 2, ...) because ids are unique only within each curator.
---@param ... lese.Curator
---@return lese.Curator
function M.compose_curators(...)
  local curators = { ... }
  return define.curator({
    name = compose_name("compose_curators", "curator", curators),
    curate = function(ctx, params)
      local out = piped(ctx, renumbering())
      for _, curator in ipairs(curators) do
        curator.curate(out, params)
      end
    end,
  })
end

---A matcher that runs the matchers in turn, each on what the previous let
---through.
---@param ... lese.Matcher
---@return lese.Matcher
function M.compose_matchers(...)
  local matchers = { ... }
  return define.matcher({
    name = compose_name("compose_matchers", "matcher", matchers),
    match = function(ctx, params)
      local items = params.items
      for _, matcher in ipairs(matchers) do
        local found = {}
        matcher.match(
          ctx:derive({
            sink = function(emitted)
              for _, item in ipairs(emitted) do
                found[#found + 1] = item
              end
            end,
          }),
          { query = params.query, items = items }
        )
        items = found
      end
      ctx:emit(items)
    end,
  })
end

---A sorter that runs the sorters in turn.
---@param ... lese.Sorter
---@return lese.Sorter
function M.compose_sorters(...)
  local sorters = { ... }
  return define.sorter({
    name = compose_name("compose_sorters", "sorter", sorters),
    sort = function(ctx, params)
      for _, sorter in ipairs(sorters) do
        sorter.sort(ctx, params)
      end
    end,
  })
end

---A renderer that runs the renderers in turn.
---@param ... lese.Renderer
---@return lese.Renderer
function M.compose_renderers(...)
  local renderers = { ... }
  return define.renderer({
    name = compose_name("compose_renderers", "renderer", renderers),
    render = function(ctx, params)
      for _, renderer in ipairs(renderers) do
        renderer.render(ctx, params)
      end
    end,
  })
end

---A previewer that returns the first preview a previewer gives.
---@param ... lese.Previewer
---@return lese.Previewer
function M.compose_previewers(...)
  local previewers = { ... }
  return define.previewer({
    name = compose_name("compose_previewers", "previewer", previewers),
    preview = function(ctx, params)
      for _, previewer in ipairs(previewers) do
        local result = previewer.preview(ctx, params)
        if result ~= nil then
          return result
        end
      end
      return nil
    end,
  })
end

---An action that invokes every action in order and keeps the picker open
---when any of them asks to.
---@param ... lese.Action
---@return lese.Action
function M.compose_actions(...)
  local actions = { ... }
  return define.action({
    name = compose_name("compose_actions", "action", actions),
    invoke = function(ctx, params)
      local keep = false
      for _, action in ipairs(actions) do
        if action.invoke(ctx, params) == true then
          keep = true
        end
      end
      return keep
    end,
  })
end

return M
