local t = require("lese.testing")
local host = require("lese.host")
local define = require("lese.define")
local custom = require("lese.custom")
local command = require("lese.command")
local session = require("lese.core.session")
local ui_picker = require("lese.ui.picker")

host.cmd("runtime! plugin/lese.vim plugin/lese/*.vim")

local BORDER = { "+", "-", "+", "|", "+", "-", "+", "|" }

local coordinator = define.coordinator({
  name = "test.coordinator",
  style = function(theme)
    return { input = theme.border, list = theme.border, preview = theme.border }
  end,
  layout = function()
    return {
      input = { row = 1, col = 1, width = 30, height = 1 },
      list = { row = 4, col = 1, width = 30, height = 5 },
      preview = { row = 1, col = 34, width = 30, height = 9 },
    }
  end,
})

local fruits = define.source({
  name = "test.fruits",
  collect = function(ctx)
    for i, v in ipairs({ "apple", "banana", "cherry" }) do
      ctx:emit({ id = i, value = v, detail = {} })
    end
  end,
})

local contains = define.matcher({
  name = "test.contains",
  match = function(ctx, params)
    for _, item in ipairs(params.items) do
      local s = string.find(item.value, params.query, 1, true)
      if s then
        ctx:emit({
          id = item.id,
          value = item.value,
          detail = item.detail,
          decorations = params.query ~= "" and { { column = s, length = #params.query } } or {},
        })
      end
    end
  end,
})

local invoked

local function setup()
  invoked = {}
  session.clear()
  custom.load_function(function(x)
    x.refine_setting({ coordinator = coordinator, theme = { border = BORDER, divider = {} } })
    x.refine_action_picker({ matchers = { contains }, coordinator = coordinator })
    local function record(name)
      return define.action({
        name = "test." .. name,
        invoke = function(_, params)
          invoked[#invoked + 1] = { name = name, item = params.item and params.item.value }
        end,
      })
    end
    x.define_picker_from_source("fruit", fruits, {
      matchers = { contains },
      previewers = {
        define.previewer({
          name = "test.previewer",
          preview = function(_, params)
            return { content = { "about " .. params.item.value } }
          end,
        }),
      },
      actions = { pick = record("pick"), other = record("other") },
      default_action = "pick",
    })
  end)
end

-- Vim cannot run input() without a terminal, so the reader stands in for the
-- user: it runs while the picker is open and returns what they would accept.
local function run(readers, fn)
  local original = ui_picker.read
  local calls = 0
  ---@diagnostic disable-next-line: duplicate-set-field
  ui_picker.read = function(picker)
    calls = calls + 1
    local reader = readers[calls]
    if not reader then
      return nil
    end
    return reader(picker)
  end
  local ok, err = pcall(fn)
  ui_picker.read = original
  if not ok then
    error(err, 0)
  end
end

local function settle(picker)
  host.wait(2000, function()
    return not picker.model:busy()
  end)
  picker.preview_due = 0
  picker:tick()
  picker:render()
end

local function buffer_lines(component)
  return host.fn.getbufline(component.window.bufnr, 1, "$")
end

t.describe("ui.picker", function()
  t.it("shows the matched rows and runs the default action on the cursor row", function()
    setup()
    local list, input
    run({
      function(picker)
        picker.model:set_query("an")
        settle(picker)
        list = buffer_lines(picker.list)
        input = buffer_lines(picker.input)[1]
        return "an"
      end,
    }, function()
      command.start(assert(custom.get("fruit")), {})
    end)
    t.eq(list, { "banana" })
    t.ok(input:find("^> an%s+1/3$"), input)
    t.eq(invoked, { { name = "pick", item = "banana" } })
  end)

  t.it("moves the cursor through the <Plug> mapping path", function()
    setup()
    run({
      function(picker)
        settle(picker)
        host.call("lese#internal#dispatch", { type = "move-cursor", amount = 1 })
        settle(picker)
        return ""
      end,
    }, function()
      command.start(assert(custom.get("fruit")), {})
    end)
    t.eq(invoked, { { name = "pick", item = "banana" } })
  end)

  t.it("runs the action lese#action() names", function()
    setup()
    run({
      function(picker)
        settle(picker)
        host.call("lese#action", "other")
        return ""
      end,
    }, function()
      command.start(assert(custom.get("fruit")), {})
    end)
    t.eq(invoked, { { name = "other", item = "apple" } })
  end)

  t.it("lets the user choose an action from the action list", function()
    setup()
    run({
      function(picker)
        settle(picker)
        host.call("lese#action", "@select")
        return ""
      end,
      function(picker)
        t.eq(picker.name, "@action")
        picker.model:set_query("oth")
        settle(picker)
        return "oth"
      end,
    }, function()
      command.start(assert(custom.get("fruit")), {})
    end)
    t.eq(invoked, { { name = "other", item = "apple" } })
  end)

  t.it("shows the preview of the cursor row", function()
    setup()
    local preview
    run({
      function(picker)
        settle(picker)
        settle(picker)
        preview = buffer_lines(picker.preview)
        return nil
      end,
    }, function()
      command.start(assert(custom.get("fruit")), {})
    end)
    t.eq(preview, { "about apple" })
  end)

  t.it("closes every window and runs nothing when cancelled", function()
    setup()
    local windows
    run({
      function(picker)
        settle(picker)
        windows = { picker.input.window.winid, picker.list.window.winid }
        return nil
      end,
    }, function()
      command.start(assert(custom.get("fruit")), {})
    end)
    t.eq(invoked, {})
    for _, winid in ipairs(windows) do
      t.eq(host.fn.win_gettype(winid), "unknown")
    end
  end)

  t.it("saves the session and resumes it with its query", function()
    setup()
    run({
      function(picker)
        picker.model:set_query("err")
        settle(picker)
        return nil
      end,
    }, function()
      command.start(assert(custom.get("fruit")), {})
    end)
    local saved = assert(session.load("fruit"))
    t.eq(saved.context.query, "err")
    local list
    run({
      function(picker)
        settle(picker)
        list = buffer_lines(picker.list)
        return nil
      end,
    }, function()
      command.resume("fruit")
    end)
    t.eq(list, { "cherry" })
  end)

  t.it("opens the help listing the picker keys", function()
    setup()
    local help
    run({
      function(picker)
        settle(picker)
        host.call("lese#internal#dispatch", { type = "help-component-toggle" })
        settle(picker)
        help = table.concat(buffer_lines(picker.help), "\n")
        return nil
      end,
    }, function()
      command.start(assert(custom.get("fruit")), {})
    end)
    t.ok(help:lower():find("<c-t> ➙ list-first", 1, true), help)
    t.ok(help:find("^Page 1/%d"), help)
  end)
end)

t.describe(":Lese", function()
  t.it("says which pickers exist when the name is unknown", function()
    setup()
    host.cmd("messages clear")
    command.lese("nothing")
    local messages = host.call("execute", "messages")
    t.ok(
      messages:find("no picker 'nothing' is found. Available pickers are: fruit", 1, true),
      messages
    )
  end)

  t.it("starts from the -input= query", function()
    setup()
    local query
    run({
      function(picker)
        query = picker.model.query
        return nil
      end,
    }, function()
      command.lese("-input=ban fruit")
    end)
    t.eq(query, "ban")
  end)
end)
