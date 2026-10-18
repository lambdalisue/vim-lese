local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

t.describe("builtin.source.quickfix", function()
  t.it("emits each entry with its position", function()
    host.cmd("silent! enew")
    host.cmd("setlocal bufhidden=hide")
    local bufnr = host.fn.bufnr("%")
    host.fn.setqflist({
      { bufnr = bufnr, lnum = 3, col = 2, end_col = 5, text = "first" },
      { bufnr = bufnr, lnum = 7, col = 0, text = "second" },
    }, "r")
    local items = t.collect(builtin.source.quickfix())
    t.eq(t.values(items), { "first", "second" })
    t.eq(items[1].detail.bufnr, bufnr)
    t.eq(items[1].detail.line, 3)
    t.eq(items[1].detail.column, 2)
    t.eq(items[1].detail.quickfix.text, "first")
    t.eq(items[1].decorations, { { column = 2, length = 3 } })
    t.eq(items[2].decorations, {})
    t.ok(items[1].id ~= items[2].id)
  end)
end)
