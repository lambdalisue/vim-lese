local t = require("lese.testing")
local define = require("lese.define")
local screen = require("lese.testing.screen")
local json = require("lese.testing.json")

local fruits = define.source({
  name = "test.fruits",
  collect = function(ctx)
    for i, v in ipairs({ "apple", "banana", "cherry" }) do
      ctx:emit({ id = i, value = v, detail = {} })
    end
  end,
})

t.describe("t.picker", function()
  t.it("shows the header and one line per row with the cursor marked", function()
    local p = t.picker({ name = "fruit", source = fruits })
    t.eq(
      p:screen(),
      table.concat({
        "fruit >   3/3",
        "> apple",
        "  banana",
        "  cherry",
      }, "\n")
    )
  end)

  t.it("brackets what the matcher matched", function()
    local p = t.picker({ name = "fruit", source = fruits }):type("an")
    t.eq(p:screen(), table.concat({ "fruit > an  1/3", "> b[an]ana" }, "\n"))
  end)

  t.it("moves the cursor and marks selected rows with keys", function()
    local p = t.picker({ name = "fruit", source = fruits }):press("<C-j>"):press("<C-n>")
    t.eq(p:screen(), table.concat({ "fruit >   3/3", " *apple", "  banana", "> cherry" }, "\n"))
  end)

  t.it("deletes the last character of the query with <BS>", function()
    local p = t.picker({ source = fruits }):type("ap"):press("<BS>")
    t.eq(p.model.query, "a")
  end)

  t.it("rejects a key it does not know", function()
    t.raises(function()
      t.picker({ source = fruits }):press("<C-z>")
    end, "unknown key <C-z>")
  end)

  t.it("invokes the default action with the cursor item", function()
    local seen
    local p = t.picker({
      source = fruits,
      actions = {
        pick = define.action({
          name = "test.pick",
          invoke = function(_, params)
            seen = params.item.value
          end,
        }),
      },
      default_action = "pick",
    })
    p:press("<C-n>"):invoke()
    t.eq(seen, "banana")
  end)

  t.it("records what failed in a stage", function()
    local p = t.picker({
      source = define.source({
        name = "test.broken",
        collect = function()
          error("broken on purpose")
        end,
      }),
    })
    t.eq(#p.errors, 1)
    t.raises(function()
      p:check()
    end, "broken on purpose")
  end)
end)

t.describe("a module that never checkpoints", function()
  t.it("is reported with whole milliseconds", function()
    local contract = require("lese.core.contract")
    local warned = {}
    local saved = contract.warn
    ---@diagnostic disable-next-line: duplicate-set-field
    contract.warn = function(message)
      warned[#warned + 1] = message
    end
    local ok, err = pcall(t.run, "test.busy", function()
      local stop, spins = os.clock() + 0.08, 0
      while os.clock() < stop do
        spins = spins + 1
      end
      return spins
    end)
    contract.warn = saved
    t.ok(ok, tostring(err))
    t.ok(
      warned[1] and warned[1]:find("test.busy ran %d+ ms without ctx:checkpoint"),
      tostring(warned[1])
    )
  end)
end)

t.describe("screen.mark", function()
  t.it("merges touching decorations into one bracket", function()
    t.eq(
      screen.mark("abcdef", { { column = 1, length = 2 }, { column = 3, length = 1 } }),
      "[abc]def"
    )
  end)

  t.it("leaves decorations with their own highlight alone", function()
    t.eq(screen.mark("abc", { { column = 1, length = 1, highlight = "Special" } }), "abc")
  end)
end)

t.describe("json.encode", function()
  t.it("encodes values with sorted object keys", function()
    t.eq(json.encode({ b = 1, a = { true, "x\n" }, c = {} }), '{"a":[true,"x\\n"],"b":1,"c":[]}')
  end)
end)
