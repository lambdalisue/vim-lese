-- The inside of bin/lese-run: run a picker from custom.lua headlessly and
-- print what it shows.

local host = require("lese.host")
local contract = require("lese.core.contract")
local custom = require("lese.custom")
local driver_mod = require("lese.testing.driver")
local screen = require("lese.testing.screen")
local json = require("lese.testing.json")

local M = {}

M.USAGE = [[
usage: lese-run [--host=nvim|vim|both] [--rtp DIR]... [--custom FILE]
                <picker> [ARG]... [--query QUERY] [--press KEY]... [--limit N]
                [--select N]... [--preview N] [--action NAME] [--json]

  --custom FILE   load pickers from FILE instead of the default custom.lua
  --rtp DIR       add DIR (an extension under development) to 'runtimepath'
  --query QUERY   type QUERY into the picker
  --press KEY     press a picker key after typing (<C-n>, <C-p>, <F3>, ...)
  --limit N       rows to show (default 20)
  --select N      select the N-th row (1-based)
  --preview N     preview the N-th row
  --action NAME   invoke action NAME on the cursor row; "default" for the
                  picker's default action
  --json          print JSON instead of text
  --host=both     run on Neovim and Vim and fail when their outputs differ]]

---@class lese.CliOptions
---@field picker string
---@field args string[]
---@field query? string
---@field press string[]
---@field limit integer
---@field select integer[]
---@field preview? integer
---@field action? string
---@field json boolean
---@field custom? string

---@param argv string[]
---@return lese.CliOptions
function M.parse(argv)
  local opts = { args = {}, press = {}, select = {}, limit = 20, json = false }
  local i = 1
  local function value(flag)
    i = i + 1
    local v = argv[i]
    if v == nil then
      error(flag .. " needs a value", 0)
    end
    return v
  end
  while i <= #argv do
    local arg = argv[i]
    if arg == "--query" then
      opts.query = value(arg)
    elseif arg == "--press" then
      opts.press[#opts.press + 1] = value(arg)
    elseif arg == "--limit" then
      opts.limit = assert(tonumber(value(arg)), "--limit needs a number")
    elseif arg == "--select" then
      opts.select[#opts.select + 1] = assert(tonumber(value(arg)), "--select needs a number")
    elseif arg == "--preview" then
      opts.preview = assert(tonumber(value(arg)), "--preview needs a number")
    elseif arg == "--action" then
      opts.action = value(arg)
    elseif arg == "--custom" then
      opts.custom = value(arg)
    elseif arg == "--json" then
      opts.json = true
    elseif arg == "--" then
      for k = i + 1, #argv do
        opts.args[#opts.args + 1] = argv[k]
      end
      break
    elseif arg:sub(1, 2) == "--" then
      error("unknown option " .. arg, 0)
    elseif not opts.picker then
      opts.picker = arg
    else
      opts.args[#opts.args + 1] = arg
    end
    i = i + 1
  end
  if not opts.picker then
    error("a picker name is required", 0)
  end
  return opts
end

local function messages()
  return host.call("execute", "messages")
end

---Run the picker the options describe and return the output and whether it
---succeeded.
---@param opts lese.CliOptions
---@return string output
---@return boolean ok
function M.run(opts)
  contract.strict = true
  local warnings = {}
  ---@diagnostic disable-next-line: duplicate-set-field
  contract.warn = function(message)
    warnings[#warnings + 1] = message
  end
  if opts.custom then
    local main, err = loadfile(opts.custom)
    if not main then
      error(err, 0)
    end
    custom.load_function(main())
  else
    custom.load()
  end
  local definition = custom.get(opts.picker)
  if not definition then
    error(
      string.format(
        "no picker '%s' is found. Available pickers are: %s",
        opts.picker,
        table.concat(custom.names(), ", ")
      ),
      0
    )
  end
  local built = definition.build(opts.args)
  local driver = driver_mod.new({
    name = definition.name,
    source = built.source,
    matchers = built.matchers,
    sorters = definition.sorters,
    renderers = definition.renderers,
    previewers = definition.previewers,
    actions = definition.actions,
    default_action = definition.default_action,
    args = opts.args,
    height = opts.limit,
  })
  if opts.query then
    driver:query(opts.query)
  end
  for _, key in ipairs(opts.press) do
    driver:press(key)
  end
  for _, row in ipairs(opts.select) do
    driver.model:select(driver.model.offset + row)
  end
  driver:wait()

  local preview
  if opts.preview then
    driver.model:move_cursor_at(driver.model.offset + opts.preview)
    driver:wait()
    preview = driver:preview()
  end

  local action_output
  if opts.action then
    local name = opts.action == "default" and definition.default_action or opts.action
    local before = messages()
    local keep = driver:invoke(name)
    local after = messages()
    local new = after:sub(1, #before) == before and after:sub(#before + 1) or after
    action_output = { name = name, keep = keep == true, messages = new:gsub("^\n", "") }
  end

  local model = driver.model
  local ok = #driver.errors == 0
  if opts.json then
    local items = {}
    local line = model:line()
    for i, item in ipairs(model.visible) do
      items[i] = {
        value = item.value,
        label = item.label,
        decorations = item.decorations or {},
        cursor = i == line,
        selected = model.selection[item.id] == true,
      }
    end
    return json.encode({
      picker = model.name,
      args = model.args,
      query = model.query,
      collected = #model.collected,
      filtered = #model.filtered,
      truncated = model.truncated,
      items = items,
      preview = preview,
      action = action_output,
      errors = driver.errors,
      warnings = warnings,
    }),
      ok
  end
  local lines = screen.lines(model)
  if opts.preview then
    for _, l in ipairs(screen.preview(preview)) do
      lines[#lines + 1] = l
    end
  end
  if action_output then
    lines[#lines + 1] = string.format(
      "--- action %s%s ---",
      action_output.name,
      action_output.keep and " (keeps the picker open)" or ""
    )
    for l in string.gmatch(action_output.messages, "[^\n]+") do
      lines[#lines + 1] = l
    end
  end
  for _, w in ipairs(warnings) do
    lines[#lines + 1] = "warning: " .. w
  end
  for _, e in ipairs(driver.errors) do
    lines[#lines + 1] = "error: " .. e
  end
  driver:close()
  return table.concat(lines, "\n"), ok
end

---Read the NUL-separated arguments bin/lese-run wrote, empty ones included.
---@param path? string
---@return string[]
function M.read_args(path)
  local argv = {}
  local file = path and io.open(path, "rb")
  if not file then
    return argv
  end
  local data = file:read("*a")
  file:close()
  local start = 1
  while start <= #data do
    local stop = data:find("\0", start, true)
    if not stop then
      argv[#argv + 1] = data:sub(start)
      break
    end
    argv[#argv + 1] = data:sub(start, stop - 1)
    start = stop + 1
  end
  return argv
end

---Entry point for bin/lese-run: print the output and quit with its status.
function M.main()
  local argv = M.read_args(os.getenv("LESE_RUN_ARGS_FILE"))
  for _, arg in ipairs(argv) do
    if arg == "-h" or arg == "--help" then
      local out = io.stdout
      out:write(M.USAGE, "\n")
      out:flush()
      host.cmd("qall!")
      return
    end
  end
  local out = io.stdout
  local ok, output, success = pcall(function()
    return M.run(M.parse(argv))
  end)
  if not ok then
    out:write("error: ", tostring(output), "\n")
    out:flush()
    host.cmd("cquit 2")
    return
  end
  out:write(output, "\n")
  out:flush()
  if success then
    host.cmd("qall!")
  else
    host.cmd("cquit 1")
  end
end

return M
