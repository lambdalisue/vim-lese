-- What :Lese, :LeseResume, :LeseSession, :LeseCustom and :LeseCustomReload do.

local host = require("lese.host")
local custom = require("lese.custom")
local define = require("lese.define")
local session = require("lese.core.session")
local scheduler_mod = require("lese.core.scheduler")
local context = require("lese.core.context")
local ui_picker = require("lese.ui.picker")
local args_mod = require("lese.core.args")
local contract = require("lese.core.contract")

local M = {}

local zindex = 50

-- Pickers that are part of lese itself are not saved as sessions.
local SESSION_EXCLUDED = { ["@action"] = true, ["@session"] = true }

local function fail(message)
  host.echo("[lese] " .. message, "ErrorMsg")
end

local function action_source(actions)
  local names = {}
  for name in pairs(actions) do
    names[#names + 1] = name
  end
  table.sort(names)
  return define.source({
    name = "@action",
    collect = function(ctx)
      for i, name in ipairs(names) do
        ctx:emit({ id = i, value = name, detail = { action = actions[name] } })
      end
    end,
  })
end

---Run an action as a task and wait for it, external commands included.
---@param name string
---@param action lese.Action
---@param params lese.InvokeParams
---@return boolean? keep
local function invoke(name, action, params)
  local s = scheduler_mod.new()
  local result
  local task = s:spawn(function()
    result = action.invoke(context.new({ scheduler = s, host = host, name = name }), params)
  end, { name = name })
  while not task:finished() do
    s:drain()
    if not task:finished() then
      host.wait(10, function()
        return task.status == "ready"
      end)
    end
  end
  if task.status == "failed" then
    error(task.traceback or tostring(task.error), 0)
  end
  return result
end

---@class lese.StartOptions
---@field args? string[]
---@field query? string                  -- the query to start with (-input=)
---@field context? lese.PickerContext    -- resume from here
---@field save_session? boolean          -- default true

---Open picker `definition` and run the action the user chooses.
---@param definition lese.PickerDefinition
---@param opts? lese.StartOptions
---@return boolean? cancelled
function M.start(definition, opts)
  opts = opts or {}
  local setting = custom.setting()
  local built = definition.build()
  local saved = opts.context
  local item_picker = ui_picker.new({
    name = definition.name,
    source = built.source,
    matchers = built.matchers,
    sorters = definition.sorters,
    renderers = definition.renderers,
    previewers = definition.previewers,
    coordinator = definition.coordinator or setting.coordinator,
    theme = definition.theme or setting.theme,
    args = opts.args,
    zindex = zindex,
    context = saved,
  })
  if opts.query and not saved then
    item_picker:set_query(opts.query)
  end
  zindex = zindex + ui_picker.ZINDEX_ALLOCATION

  local ok, err = pcall(function()
    item_picker:open()
    while true do
      host.cmd("redraw")
      local result = item_picker:start()
      if not result then
        return true
      end
      local action_name = result.action
      if action_name == "@select" then
        local action_params = custom.action_picker()
        local action_picker = ui_picker.new({
          name = "@action",
          source = action_source(definition.actions),
          matchers = action_params.matchers,
          coordinator = action_params.coordinator,
          theme = setting.theme,
          zindex = zindex,
        })
        zindex = zindex + ui_picker.ZINDEX_ALLOCATION
        action_picker:open()
        local ok_action, chosen = pcall(action_picker.start, action_picker)
        action_picker:close()
        action_picker:dispose()
        zindex = zindex - ui_picker.ZINDEX_ALLOCATION
        if not ok_action then
          error(chosen, 0)
        end
        if not chosen or not chosen.item then
          action_name = nil
        else
          action_name = chosen.item.value
        end
      elseif not action_name then
        action_name = definition.default_action
      end
      if action_name then
        local action = definition.actions[action_name]
        if not action then
          local names = {}
          for name in pairs(definition.actions) do
            names[#names + 1] = name
          end
          table.sort(names)
          error(
            string.format(
              "no action '%s' is found. Available actions are: %s",
              action_name,
              table.concat(names, ", ")
            ),
            0
          )
        end
        result.action = nil
        result._picker = { definition = definition, setting = setting, zindex = zindex }
        if not invoke(action_name, action, result) then
          return false
        end
      end
    end
  end)
  item_picker:close()
  item_picker:dispose()
  zindex = zindex - ui_picker.ZINDEX_ALLOCATION
  if opts.save_session ~= false and not SESSION_EXCLUDED[definition.name] then
    session.save({
      name = definition.name,
      args = opts.args or {},
      context = item_picker.model:snapshot(),
    })
  end
  host.cmd("redraw")
  if not ok then
    error(err, 0)
  end
  return err
end

---Prepare the editor for a picker, run `fn`, and restore it whatever happens.
local function with_picker(fn)
  contract.strict = host.eval("get(g:, 'lese_strict', 0)") == 1
  host.call("lese#internal#picker#setup")
  local ok, err = pcall(fn)
  host.call("lese#internal#picker#teardown")
  if not ok then
    fail(tostring(err))
  end
end

local function picker_names()
  return table.concat(custom.names(), ", ")
end

---:Lese [-input={query}] {name} [{args}]
---@param cmdline string
function M.lese(cmdline)
  custom.load()
  local args = args_mod.parse(cmdline)
  local index
  for i, arg in ipairs(args) do
    if arg:sub(1, 1) ~= "-" then
      index = i
      break
    end
  end
  if not index then
    fail("a picker name is required. Available pickers are: " .. picker_names())
    return
  end
  local query
  for i = 1, index - 1 do
    local value = args[i]:match("^%-input=(.*)$")
    if value then
      query = value
    end
  end
  local name = args[index]
  local definition = custom.get(name)
  if not definition then
    fail(string.format("no picker '%s' is found. Available pickers are: %s", name, picker_names()))
    return
  end
  local rest = {}
  for i = index + 1, #args do
    rest[#rest + 1] = args[i]
  end
  with_picker(function()
    M.start(definition, { args = rest, query = query })
  end)
end

---:LeseResume [{name}][#{number}]
---@param filter string
function M.resume(filter)
  custom.load()
  local name, number = filter:match("^([^#]*)#?(%d*)$")
  name = name or ""
  local n = tonumber(number) or 1
  local found = session.load(name ~= "" and name or nil, n)
  if not found then
    fail(string.format("picker session %s#%d is not available", name, n))
    return
  end
  local definition = custom.get(found.name)
  if not definition then
    fail(
      string.format(
        "no picker '%s' is found. Available pickers are: %s",
        found.name,
        picker_names()
      )
    )
    return
  end
  with_picker(function()
    M.start(definition, { args = found.args, context = found.context })
  end)
end

local function session_definition()
  local builtin = require("lese.builtin")
  return {
    name = "@session",
    build = function()
      return {
        source = define.source({
          name = "@session",
          collect = function(ctx)
            for i, s in ipairs(session.list()) do
              ctx:emit({ id = i, value = "#" .. i, detail = s })
            end
          end,
        }),
        matchers = { builtin.matcher.substring() },
      }
    end,
    sorters = {},
    renderers = {
      define.renderer({
        name = "@session",
        render = function(_, params)
          for _, item in ipairs(params.items) do
            local parts = { item.value, item.detail.name }
            for _, arg in ipairs(item.detail.args) do
              parts[#parts + 1] = arg
            end
            item.label = table.concat(parts, " ")
          end
        end,
      }),
    },
    previewers = {
      define.previewer({
        name = "@session",
        preview = function(_, params)
          local s = params.item.detail
          local c = s.context
          local lines = {
            "# Session: " .. params.item.value,
            "",
            "Source: " .. s.name,
            "Query: " .. (c.query ~= "" and c.query or "(empty)"),
            "Total items: " .. #c.collected,
            "Filtered items: " .. #c.filtered,
            "",
            "## Filtered Items:",
            "",
          }
          for _, item in ipairs(c.filtered) do
            lines[#lines + 1] = (c.selection[item.id] and "[x] " or "[ ] ") .. item.value
          end
          if #c.filtered == 0 then
            lines[#lines + 1] = "(no items)"
          end
          return { content = lines, filetype = "markdown" }
        end,
      }),
    },
    actions = {
      resume = define.action({
        name = "@session.resume",
        invoke = function(ctx, params)
          if params.item then
            -- Resume after this picker closed; pickers do not nest here.
            local value = params.item.value
            ctx.host.defer(0, function()
              ctx.host.cmd("LeseResume " .. value)
            end)
          end
        end,
      }),
    },
    default_action = "resume",
  }
end

---:LeseSession
function M.session()
  custom.load()
  with_picker(function()
    M.start(session_definition())
  end)
end

---:LeseCustom
function M.custom()
  custom.edit()
end

---:LeseCustomReload
function M.custom_reload()
  custom.load({ reload = true, verbose = true })
end

local COMMANDS = {
  lese = M.lese,
  resume = M.resume,
  session = M.session,
  custom = M.custom,
  custom_reload = M.custom_reload,
}

---Called by lese#internal#command#call().
---@param name string
---@param args string
function M.call(name, args)
  local fn = COMMANDS[name]
  if fn then
    fn(args)
  end
end

---Complete picker names for :Lese.
---@param arglead string
---@return any
function M.complete(arglead)
  custom.load()
  local out = {}
  for _, name in ipairs(custom.names()) do
    if name:sub(1, #arglead) == arglead then
      out[#out + 1] = name
    end
  end
  return host.export(out)
end

---Complete session filters for :LeseResume.
---@param arglead string
---@param cmdline string
---@return any
function M.complete_resume(arglead, cmdline)
  local out = {}
  local sessions = session.list()
  if cmdline:find("#", 1, true) then
    local name = arglead:match("^([^#]*)") or ""
    local count = 0
    for _, s in ipairs(sessions) do
      if name == "" or s.name == name then
        count = count + 1
        local candidate = name .. "#" .. count
        if candidate:sub(1, #arglead) == arglead then
          out[#out + 1] = candidate
        end
      end
    end
  else
    local seen = {}
    for _, s in ipairs(sessions) do
      if not seen[s.name] and s.name:sub(1, #arglead) == arglead then
        seen[s.name] = true
        out[#out + 1] = s.name
      end
    end
  end
  return host.export(out)
end

return M
