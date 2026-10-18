local t = require("lese.testing")
local define = require("lese.define")

t.describe("define", function()
  t.it("requires a name", function()
    t.raises(function()
      define.source({ collect = function() end })
    end, "define.source() needs a 'name'")
  end)

  t.it("requires the module's function", function()
    t.raises(function()
      define.matcher({ name = "my.matcher" })
    end, "matcher 'my.matcher' needs a 'match' function")
  end)
end)

t.describe("define.source", function()
  t.it("passes emitted items through", function()
    local source = define.source({
      name = "my.source",
      collect = function(ctx, params)
        for _, arg in ipairs(params.args) do
          ctx:emit(t.item(arg))
        end
      end,
    })
    t.eq(t.values(t.collect(source, { args = { "a", "b" } })), { "a", "b" })
  end)

  t.it("names the module, the item and the field when an item breaks the contract", function()
    local source = define.source({
      name = "my.source",
      collect = function(ctx)
        ctx:emit(t.item("a"))
        local broken = { id = 2, value = 2, detail = {} } ---@type any
        ctx:emit(broken)
      end,
    })
    t.raises(function()
      t.collect(source)
    end, "lese: source 'my.source' emitted item #2: field 'value' must be a string, got 2")
  end)

  t.it("requires an id", function()
    local source = define.source({
      name = "my.source",
      collect = function(ctx)
        ctx:emit({ value = "a", detail = {} })
      end,
    })
    t.raises(function()
      t.collect(source)
    end, "emitted item #1 (value \"a\"): field 'id' must be set")
  end)

  t.it("requires detail to be a table", function()
    local source = define.source({
      name = "my.source",
      collect = function(ctx)
        ctx:emit({ id = 1, value = "a" })
      end,
    })
    t.raises(function()
      t.collect(source)
    end, "field 'detail' must be a table, got nil")
  end)
end)

t.describe("define.sorter", function()
  t.it("rejects a sorter that changes the number of items", function()
    local sorter = define.sorter({
      name = "my.sorter",
      sort = function(_, params)
        params.items[#params.items] = nil
      end,
    })
    t.raises(function()
      t.sort(sorter, t.items({ "a", "b" }))
    end, "sorter 'my.sorter' changed the number of items from 2 to 1")
  end)
end)

t.describe("define.renderer", function()
  t.it("rejects a decoration past the end of the label", function()
    local renderer = define.renderer({
      name = "my.renderer",
      render = function(_, params)
        for _, item in ipairs(params.items) do
          item.decorations = { { column = 2, length = 5 } }
        end
      end,
    })
    t.raises(function()
      t.render(renderer, t.items({ "abc" }))
    end, 'decorations[1] spans bytes 2-6, past the end of the 3-byte label "abc"')
  end)
end)

t.describe("define.previewer", function()
  t.it("rejects content that is not a list of strings", function()
    local previewer = define.previewer({
      name = "my.previewer",
      preview = function()
        return { content = { 1 } }
      end,
    })
    t.raises(function()
      t.preview(previewer, t.item("a"))
    end, "previewer 'my.previewer' returned content[1] that is 1, not a string")
  end)
end)
