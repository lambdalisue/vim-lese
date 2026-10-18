local t = require("lese.testing")
local numerical = require("lese.builtin.sorter.numerical")

t.describe("builtin.sorter.numerical", function()
  t.it("is named builtin.sorter.numerical", function()
    t.eq(numerical().name, "builtin.sorter.numerical")
  end)

  t.it("orders items by the number in their value", function()
    t.eq(t.values(t.sort(numerical(), t.items({ "10", "9", "100", "-1", "1.5" }))), {
      "-1",
      "1.5",
      "9",
      "10",
      "100",
    })
  end)

  t.it("reverses the order with reverse", function()
    t.eq(
      t.values(t.sort(numerical({ reverse = true }), t.items({ "1", "3", "2" }))),
      { "3", "2", "1" }
    )
  end)

  t.it("orders by what key returns, a number or a string", function()
    local items = { t.item("x", { size = 20 }), t.item("y", { size = "3" }) }
    local sorter = numerical({
      key = function(item)
        return item.detail.size
      end,
    })
    t.eq(t.values(t.sort(sorter, items)), { "y", "x" })
  end)

  t.it("puts items without a number after the others, in their order", function()
    t.eq(t.values(t.sort(numerical(), t.items({ "b", "2", "a", "1" }))), { "1", "2", "b", "a" })
  end)

  t.it("keeps the order of items with equal numbers", function()
    local items = t.items({ "1", "01", "1.0" })
    t.eq(t.values(t.sort(numerical(), items)), { "1", "01", "1.0" })
  end)
end)
