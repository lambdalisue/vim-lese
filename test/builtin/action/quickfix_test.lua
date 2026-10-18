local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

local function entries()
  local result = {}
  for i, e in ipairs(host.fn.getqflist()) do
    result[i] = {
      name = host.fn.bufname(e.bufnr),
      lnum = e.lnum,
      col = e.col,
      end_col = e.end_col,
      text = e.text,
    }
  end
  return result
end

t.describe("builtin.action.quickfix", function()
  t.it("fills the quickfix list with the filtered items", function()
    host.fn.setqflist({}, "r")
    local items = {
      t.item("a", { path = "lese-a.txt", line = 2, column = 3, length = 4, context = "hit" }),
      t.item("b", { bufname = "lese-b.txt", line = 5 }),
    }
    local keep = t.invoke(builtin.action.quickfix(), { filtered_items = items })
    t.eq(keep, nil)
    t.eq(entries(), {
      { name = "lese-a.txt", lnum = 2, col = 3, end_col = 7, text = "hit" },
      { name = "lese-b.txt", lnum = 5, col = 0, end_col = 0, text = "" },
    })
  end)

  t.it("uses the selected items when there are any", function()
    local selected = { t.item("b", { path = "lese-b.txt", line = 1 }) }
    t.invoke(builtin.action.quickfix(), {
      selected_items = selected,
      filtered_items = { t.item("a", { path = "lese-a.txt", line = 1 }), selected[1] },
    })
    t.eq(#host.fn.getqflist(), 1)
    t.eq(host.fn.bufname(host.fn.getqflist()[1].bufnr), "lese-b.txt")
  end)

  t.it("passes what and action to setqflist()", function()
    host.fn.setqflist({}, "r")
    local items = { t.item("a", { path = "lese-a.txt", line = 1 }) }
    t.invoke(builtin.action.quickfix(), { filtered_items = items })
    local action = builtin.action.quickfix({ action = "a", what = { title = "lese" } })
    t.invoke(action, { filtered_items = items })
    t.eq(#host.fn.getqflist(), 2)
    t.eq(host.fn.getqflist({ title = 1 }).title, "lese")
  end)

  t.it("keeps the picker open with continue and runs after", function()
    host.cmd("silent! only!")
    local items = { t.item("a", { path = "lese-a.txt", line = 1 }) }
    local action = builtin.action.quickfix({ continue = true, after = "copen" })
    t.eq(t.invoke(action, { filtered_items = items }), true)
    t.eq(host.fn.getwinvar(host.fn.winnr(), "&buftype"), "quickfix")
    host.cmd("cclose")
  end)
end)

t.describe("builtin.action.default_quickfix_actions", function()
  t.it("holds quickfix and quickfix:copen", function()
    local actions = builtin.action.default_quickfix_actions
    local items = { t.item("a", { path = "lese-a.txt", line = 1 }) }
    t.eq(t.invoke(actions.quickfix, { filtered_items = items }), true)
    host.cmd("silent! only!")
    t.eq(t.invoke(actions["quickfix:copen"], { filtered_items = items }), nil)
    t.eq(host.fn.getwinvar(host.fn.winnr(), "&buftype"), "quickfix")
    host.cmd("cclose")
  end)
end)
