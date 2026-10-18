local t = require("lese.testing")
local lexical = require("lese.builtin.sorter.lexical")

t.describe("builtin.sorter.lexical", function()
  t.it("is named builtin.sorter.lexical", function()
    t.eq(lexical().name, "builtin.sorter.lexical")
  end)

  t.it("orders items by value, byte by byte", function()
    t.eq(t.values(t.sort(lexical(), t.items({ "b", "B", "a", "ab" }))), { "B", "a", "ab", "b" })
  end)

  t.it("reverses the order with reverse", function()
    t.eq(
      t.values(t.sort(lexical({ reverse = true }), t.items({ "a", "c", "b" }))),
      { "c", "b", "a" }
    )
  end)

  t.it("orders by what key returns", function()
    local items = { t.item("x", { name = "b" }), t.item("y", { name = "a" }) }
    local sorter = lexical({
      key = function(item)
        return item.detail.name
      end,
    })
    t.eq(t.values(t.sort(sorter, items)), { "y", "x" })
  end)

  t.it("keeps the order of items with equal keys", function()
    local items = {}
    for i = 1, 50 do
      items[i] = { id = i, value = i % 2 == 0 and "even" or "odd", detail = {} }
    end
    local sorted = t.sort(lexical(), items)
    local previous = { even = 0, odd = 0 }
    for _, item in ipairs(sorted) do
      t.ok(item.id > previous[item.value], "item " .. item.id .. " moved before an equal one")
      previous[item.value] = item.id
    end
    t.eq(sorted[1].value, "even")
  end)

  t.it("keeps the order of items with equal keys when reversed", function()
    local items = { t.item("a"), t.item("b"), t.item("a") }
    items[3].id = "a2"
    local sorted = t.sort(lexical({ reverse = true }), items)
    t.eq({ sorted[1].id, sorted[2].id, sorted[3].id }, { "b", "a", "a2" })
  end)
end)
