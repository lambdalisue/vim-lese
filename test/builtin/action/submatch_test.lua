local t = require("lese.testing")
local host = require("lese.host")
local define = require("lese.define")
local builtin = require("lese.builtin")
local command = require("lese.command")
local ui_picker = require("lese.ui.picker")

local fruits = define.source({
  name = "test.fruits",
  collect = function(ctx)
    for i, v in ipairs({ "apple", "banana", "cherry" }) do
      ctx:emit({ id = i, value = v, detail = {} })
    end
  end,
})

-- Stands in for the user at each picker that opens, in order.
local function run(readers, fn)
  local original = ui_picker.read
  local calls = 0
  ---@diagnostic disable-next-line: duplicate-set-field
  ui_picker.read = function(picker)
    calls = calls + 1
    local reader = readers[calls]
    return reader and reader(picker) or nil
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
end

t.describe("builtin.action.submatch", function()
  t.it("searches again within what the first query left", function()
    local picked = {}
    local definition = {
      name = "fruit",
      build = function()
        return { source = fruits, matchers = { builtin.matcher.substring() } }
      end,
      sorters = {},
      renderers = {},
      previewers = {},
      actions = {
        pick = define.action({
          name = "test.pick",
          invoke = function(_, params)
            picked[#picked + 1] = params.item.value
          end,
        }),
        sub = builtin.action.submatch({ builtin.matcher.fzf() }),
      },
      default_action = "pick",
      coordinator = builtin.coordinator.modern(),
      theme = builtin.theme.ASCII,
    }
    local inner_items
    run({
      function(picker)
        picker.model:set_query("an")
        settle(picker)
        host.call("lese#action", "sub")
        return "an"
      end,
      function(picker)
        settle(picker)
        inner_items = t.values(picker.model.filtered)
        picker.model:set_query("nn")
        settle(picker)
        return "nn"
      end,
    }, function()
      command.start(definition, {})
    end)
    t.eq(inner_items, { "banana" })
    t.eq(picked, { "banana" })
  end)

  t.it("needs a matcher", function()
    t.raises(function()
      builtin.action.submatch({})
    end, "needs at least one matcher")
  end)
end)
