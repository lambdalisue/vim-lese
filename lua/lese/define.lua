-- Define modules. Each helper (1) tells lua-language-server the module's type,
-- (2) checks what the module hands back while `contract.strict` is on, and
-- (3) requires a `name`, which errors and the help use.

local contract = require("lese.core.contract")

local M = {}

local function checked_emit(ctx, kind, name)
  local count = 0
  local sink = ctx.sink
  return ctx:derive({
    name = name,
    sink = function(items)
      for _, item in ipairs(items) do
        count = count + 1
        contract.item(kind, name, string.format("emitted item #%d", count), item)
      end
      sink(items)
    end,
  })
end

---@param def { name: string, collect: fun(ctx: lese.Context, params: lese.CollectParams) }
---@return lese.Source
function M.source(def)
  contract.definition("source", def, "collect")
  local collect = def.collect
  return {
    name = def.name,
    collect = function(ctx, params)
      if contract.strict then
        return collect(checked_emit(ctx, "source", def.name), params)
      end
      return collect(ctx:derive({ name = def.name }), params)
    end,
  }
end

---@param def { name: string, curate: fun(ctx: lese.Context, params: lese.CurateParams) }
---@return lese.Curator
function M.curator(def)
  contract.definition("curator", def, "curate")
  local curate = def.curate
  return {
    name = def.name,
    curate = function(ctx, params)
      if contract.strict then
        return curate(checked_emit(ctx, "curator", def.name), params)
      end
      return curate(ctx:derive({ name = def.name }), params)
    end,
  }
end

---@param def { name: string, match: fun(ctx: lese.Context, params: lese.MatchParams), incremental?: boolean }
---@return lese.Matcher
function M.matcher(def)
  contract.definition("matcher", def, "match")
  local match = def.match
  return {
    name = def.name,
    incremental = def.incremental,
    match = function(ctx, params)
      if contract.strict then
        return match(checked_emit(ctx, "matcher", def.name), params)
      end
      return match(ctx:derive({ name = def.name }), params)
    end,
  }
end

---@param def { name: string, sort: fun(ctx: lese.Context, params: lese.SortParams) }
---@return lese.Sorter
function M.sorter(def)
  contract.definition("sorter", def, "sort")
  local sort = def.sort
  return {
    name = def.name,
    sort = function(ctx, params)
      local before = #params.items
      sort(ctx:derive({ name = def.name }), params)
      if contract.strict then
        contract.count("sorter", def.name, before, #params.items)
      end
    end,
  }
end

---@param def { name: string, render: fun(ctx: lese.Context, params: lese.RenderParams) }
---@return lese.Renderer
function M.renderer(def)
  contract.definition("renderer", def, "render")
  local render = def.render
  return {
    name = def.name,
    render = function(ctx, params)
      local before = #params.items
      render(ctx:derive({ name = def.name }), params)
      if contract.strict then
        contract.count("renderer", def.name, before, #params.items)
        for i, item in ipairs(params.items) do
          contract.rendered(def.name, i, item)
        end
      end
    end,
  }
end

---@param def { name: string, preview: fun(ctx: lese.Context, params: lese.PreviewParams): lese.PreviewItem? }
---@return lese.Previewer
function M.previewer(def)
  contract.definition("previewer", def, "preview")
  local preview = def.preview
  return {
    name = def.name,
    preview = function(ctx, params)
      local result = preview(ctx:derive({ name = def.name }), params)
      if contract.strict then
        contract.preview(def.name, result)
      end
      return result
    end,
  }
end

---@param def { name: string, invoke: fun(ctx: lese.Context, params: lese.InvokeParams): boolean? }
---@return lese.Action
function M.action(def)
  contract.definition("action", def, "invoke")
  local invoke = def.invoke
  return {
    name = def.name,
    invoke = function(ctx, params)
      return invoke(ctx:derive({ name = def.name }), params)
    end,
  }
end

---@param def { name: string, refine: fun(ctx: lese.Context, item: lese.Item): lese.Item? }
---@return lese.Refiner
function M.refiner(def)
  contract.definition("refiner", def, "refine")
  local refine = def.refine
  return {
    name = def.name,
    refine = function(ctx, item)
      local result = refine(ctx:derive({ name = def.name }), item)
      if contract.strict and result ~= nil then
        contract.item("refiner", def.name, "returned item", result)
      end
      return result
    end,
  }
end

---@param def { name: string, style: fun(theme: lese.Theme): lese.Style, layout: fun(screen: lese.Size): lese.Layout }
---@return lese.Coordinator
function M.coordinator(def)
  contract.definition("coordinator", def, "layout")
  return def
end

return M
