-- custom.lua: the user's declaration of every picker, and the settings they
-- share. Read docs/adr/20261018-users-declare-their-pickers-in-custom-lua.md.

local define = require("lese.define")

local M = {}

---A picker declared in custom.lua, as lese keeps it.
---@class lese.PickerDefinition
---@field name string -- what `:Lese` opens it by
---@field build fun(args: string[]): { source: lese.Source, matchers: lese.Matcher[] }  -- fresh per picker
---@field sorters lese.Sorter[] -- empty when the picker declared none
---@field renderers lese.Renderer[] -- empty when the picker declared none
---@field previewers lese.Previewer[] -- empty when the picker declared none
---@field actions table<string, lese.Action> -- action name to action
---@field default_action string -- the key of `actions` invoked on <CR>
---@field coordinator? lese.Coordinator -- nil: the one set by `x.refine_setting`
---@field theme? lese.Theme -- nil: the one set by `x.refine_setting`

local state = {
  ---@type lese.Setting?
  setting = nil,
  ---@type lese.ActionPickerParams?
  action_picker = nil,
  ---@type table<string, lese.PickerDefinition>
  pickers = {},
  ---@type string[]
  order = {},
  loaded = false,
  ---@type table<string, true>
  modules = {},
}

local function default_setting()
  local builtin = require("lese.builtin")
  return { coordinator = builtin.coordinator.modern(), theme = builtin.theme.MODERN }
end

local function default_action_picker()
  local builtin = require("lese.builtin")
  return {
    matchers = { builtin.matcher.fzf() },
    coordinator = builtin.coordinator.modern({
      width_ratio = 0.4,
      height_ratio = 0.4,
      hide_preview = true,
    }),
  }
end

local function reset()
  state.setting = nil
  state.action_picker = nil
  state.pickers = {}
  state.order = {}
end

local function validate_name(name)
  if type(name) ~= "string" or name == "" then
    error("lese: a picker name must be a non-empty string", 3)
  end
  if name:sub(1, 1) == "@" then
    error(string.format("lese: picker name must not start with '@': %s", name), 3)
  end
  if state.pickers[name] then
    error(string.format("lese: picker '%s' is already defined", name), 3)
  end
end

local function validate_actions(name, params)
  if type(params.actions) ~= "table" or next(params.actions) == nil then
    error(string.format("lese: picker '%s' needs 'actions'", name), 3)
  end
  for action_name, action in pairs(params.actions) do
    if action_name:sub(1, 1) == "@" then
      error(string.format("lese: action name must not start with '@': %s", action_name), 3)
    end
    if type(action) ~= "table" or type(action.invoke) ~= "function" then
      error(
        string.format("lese: action '%s' of picker '%s' is not an action", action_name, name),
        3
      )
    end
  end
  if type(params.default_action) ~= "string" or not params.actions[params.default_action] then
    error(
      string.format(
        "lese: picker '%s' has no action '%s' to use as 'default_action'",
        name,
        tostring(params.default_action)
      ),
      3
    )
  end
end

local function register(name, build, params)
  state.pickers[name] = {
    name = name,
    build = build,
    sorters = params.sorters or {},
    renderers = params.renderers or {},
    previewers = params.previewers or {},
    actions = params.actions,
    default_action = params.default_action,
    coordinator = params.coordinator,
    theme = params.theme,
  }
  state.order[#state.order + 1] = name
end

---A curator searched once per query, as the only matcher of its picker.
---The arguments are bound here, since a resumed picker collects nothing.
---@param curator lese.Curator
---@param args string[]
---@return lese.Source source
---@return lese.Matcher matcher
function M.curator_pipeline(curator, args)
  local source = define.source({
    name = curator.name,
    collect = function() end,
  })
  local matcher = define.matcher({
    name = curator.name,
    incremental = true,
    match = function(ctx, params)
      curator.curate(ctx, { args = args, query = params.query })
    end,
  })
  return source, matcher
end

---@type lese.Entrypoint
local entrypoint = {
  define_picker_from_source = function(name, source, params)
    validate_name(name)
    if type(source) ~= "table" or type(source.collect) ~= "function" then
      error(string.format("lese: picker '%s' needs a source", name), 2)
    end
    if not params.matchers or #params.matchers == 0 then
      error(string.format("lese: picker '%s' needs at least one matcher", name), 2)
    end
    validate_actions(name, params)
    register(name, function()
      return { source = source, matchers = params.matchers }
    end, params)
  end,
  define_picker_from_curator = function(name, curator, params)
    validate_name(name)
    if type(curator) ~= "table" or type(curator.curate) ~= "function" then
      error(string.format("lese: picker '%s' needs a curator", name), 2)
    end
    validate_actions(name, params)
    register(name, function(args)
      local source, matcher = M.curator_pipeline(curator, args)
      return { source = source, matchers = { matcher } }
    end, params)
  end,
  refine_setting = function(setting)
    local current = state.setting
    state.setting = {
      coordinator = setting.coordinator or (current or default_setting()).coordinator,
      theme = setting.theme or (current or default_setting()).theme,
    }
  end,
  refine_action_picker = function(params)
    local current = state.action_picker
    state.action_picker = {
      matchers = params.matchers or (current or default_action_picker()).matchers,
      coordinator = params.coordinator or (current or default_action_picker()).coordinator,
    }
  end,
}

local function declare(chunk)
  local main = chunk()
  if type(main) ~= "function" then
    error("lese: custom.lua must return a function that takes the entrypoint", 0)
  end
  -- Declare into a fresh registry and keep it only when the whole file ran, so
  -- a broken reload leaves the pickers that worked before.
  local saved = {
    setting = state.setting,
    action_picker = state.action_picker,
    pickers = state.pickers,
    order = state.order,
  }
  reset()
  local ok, err = pcall(main, entrypoint)
  if not ok then
    state.setting = saved.setting
    state.action_picker = saved.action_picker
    state.pickers = saved.pickers
    state.order = saved.order
    error(err, 0)
  end
end

---Run a custom.lua chunk, recording the modules it loads so a reload can
---load them afresh, whether or not this run succeeds.
---@param chunk fun(): any
local function run(chunk)
  local before = {}
  for name in pairs(package.loaded) do
    before[name] = true
  end
  local ok, err = pcall(declare, chunk)
  for name in pairs(package.loaded) do
    if not before[name] and not name:match("^lese%.") and name ~= "lese" then
      state.modules[name] = true
    end
  end
  if not ok then
    error(err, 0)
  end
end

---The path of the user's custom.lua.
---@return string
function M.path()
  local host = require("lese.host")
  return host.fn.expand(host.eval("get(g:, 'lese_custom_path', '')"))
end

---The path of the default custom.lua lese ships.
---@return string
function M.default_path()
  local source = debug.getinfo(1, "S").source:sub(2)
  return (source:gsub("custom%.lua$", "assets/default_custom.lua"))
end

---@class lese.CustomLoadOptions
---@field reload? boolean   -- load again even when loaded
---@field verbose? boolean  -- say which file was loaded
---@field path? string      -- load this file instead of g:lese_custom_path

---Load custom.lua, or the default one when the user has none. A reload that
---fails keeps the pickers loaded before.
---@param opts? lese.CustomLoadOptions
function M.load(opts)
  opts = opts or {}
  if state.loaded and not opts.reload then
    return
  end
  local host = require("lese.host")
  if opts.reload then
    for name in pairs(state.modules) do
      package.loaded[name] = nil
    end
    state.modules = {}
  end
  local path = opts.path or M.path()
  local chunk, err
  if path ~= "" and host.fn.filereadable(path) == 1 then
    chunk, err = loadfile(path)
  end
  if chunk then
    local ok, run_err = pcall(run, chunk)
    if ok then
      state.loaded = true
      host.emit("LeseCustomLoaded")
      if opts.verbose then
        host.echo("[lese] custom.lua is loaded: " .. path)
      end
      return
    end
    err = run_err
  end
  if err then
    host.echo("[lese] failed to load custom.lua: " .. tostring(err), "WarningMsg")
    if state.loaded then
      return
    end
  end
  run(assert(loadfile(M.default_path())))
  state.loaded = true
  if opts.verbose then
    host.echo("[lese] the default custom.lua is loaded: " .. M.default_path())
  end
end

---Load a custom function directly; lese.testing and lese-run use it.
---@param main fun(x: lese.Entrypoint)
function M.load_function(main)
  run(function()
    return main
  end)
  state.loaded = true
end

---The coordinator and theme set by `x.refine_setting`, or the defaults.
---@return lese.Setting
function M.setting()
  return state.setting or default_setting()
end

---The matchers and coordinator set by `x.refine_action_picker`, or the defaults.
---@return lese.ActionPickerParams
function M.action_picker()
  return state.action_picker or default_action_picker()
end

---The picker declared as `name`, or nil.
---@param name string
---@return lese.PickerDefinition?
function M.get(name)
  return state.pickers[name]
end

---Picker names in the order they were defined.
---@return string[]
function M.names()
  local out = {}
  for i, name in ipairs(state.order) do
    out[i] = name
  end
  return out
end

---Open custom.lua for editing, creating it from the default on first use, and
---reload it on every write.
function M.edit()
  local host = require("lese.host")
  local path = M.path()
  if host.fn.filereadable(path) == 0 then
    host.fn.mkdir(host.fn.fnamemodify(path, ":h"), "p")
    host.fn.writefile(host.fn.readfile(M.default_path()), path)
  end
  host.cmd("edit " .. host.fn.fnameescape(path))
  host.cmd("augroup lese_custom")
  host.cmd("autocmd! * <buffer>")
  host.cmd("autocmd BufWritePost <buffer> LeseCustomReload")
  host.cmd("augroup END")
end

return M
