local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

local function scratch(lines)
  host.cmd("silent! enew")
  host.cmd("setlocal bufhidden=hide")
  host.fn.setline(1, lines)
  return host.fn.bufnr("%")
end

t.describe("builtin.source.line", function()
  t.it("emits each line of the current buffer prefixed with its number", function()
    local bufnr = scratch({ "alpha", "beta" })
    local items = t.collect(builtin.source.line())
    t.eq(t.values(items), { "1 alpha", "2 beta" })
    t.eq(items[2].detail, { bufnr = bufnr, bufname = "", line = 2, context = "beta" })
  end)

  t.it("pads the line numbers to the width of the last one", function()
    local lines = {}
    for i = 1, 10 do
      lines[i] = "l" .. i
    end
    scratch(lines)
    local values = t.values(t.collect(builtin.source.line()))
    t.eq(values[1], " 1 l1")
    t.eq(values[10], "10 l10")
  end)

  t.it("reads the buffer given as the first argument in chunks", function()
    local bufnr = scratch({ "a", "b", "c", "d", "e" })
    host.cmd("silent! enew")
    local items = t.collect(builtin.source.line({ chunk_size = 2 }), { args = { tostring(bufnr) } })
    t.eq(t.values(items), { "1 a", "2 b", "3 c", "4 d", "5 e" })
    local ids = {}
    for _, item in ipairs(items) do
      t.ok(not ids[item.id])
      ids[item.id] = true
    end
  end)
end)
