local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

local function reset()
  host.cmd("silent! tabonly!")
  host.cmd("silent! only!")
  host.cmd("silent! enew!")
end

local function file(lines)
  local p = host.fn.fnamemodify(host.fn.tempname(), ":p")
  host.fn.writefile(lines or { "one", "two", "three" }, p)
  return p
end

local function current()
  return host.fn.fnamemodify(host.fn.bufname("%"), ":p")
end

t.describe("builtin.action.open", function()
  t.it("edits detail.path in the current window", function()
    reset()
    local p = file()
    local keep = t.invoke(builtin.action.open(), { item = t.item("x", { path = p }) })
    t.eq(keep, nil)
    t.eq(current(), p)
    t.eq(host.fn.winnr("$"), 1)
  end)

  t.it("moves the cursor to detail.line and detail.column", function()
    reset()
    local p = file({ "one", "two words", "three" })
    t.invoke(builtin.action.open(), { item = t.item("x", { path = p, line = 2, column = 5 }) })
    t.eq({ host.fn.line("."), host.fn.col(".") }, { 2, 5 })
  end)

  t.it("opens with the opener and every further item with the splitter", function()
    reset()
    local a, b, c = file(), file(), file()
    local action = builtin.action.open({ opener = "tabedit", splitter = "split" })
    t.invoke(action, {
      item = t.item("a", { path = a }),
      selected_items = {
        t.item("a", { path = a }),
        t.item("b", { path = b }),
        t.item("c", { path = c }),
      },
    })
    t.eq(host.fn.tabpagenr("$"), 2)
    t.eq(host.fn.winnr("$"), 3)
    t.eq(current(), c)
  end)

  t.it("opens a buffer by detail.bufname or detail.bufnr", function()
    reset()
    local p = file()
    host.cmd("silent edit " .. host.fn.fnameescape(p))
    local bufnr = host.fn.bufnr("%")
    host.cmd("silent! enew!")
    t.invoke(builtin.action.open(), { item = t.item("x", { bufnr = bufnr, line = 3 }) })
    t.eq(host.fn.bufnr("%"), bufnr)
    t.eq(host.fn.line("."), 3)
    host.cmd("silent! enew!")
    t.invoke(builtin.action.open(), { item = t.item("x", { bufname = host.fn.bufname(bufnr) }) })
    t.eq(host.fn.bufnr("%"), bufnr)
  end)

  t.it("opens an unnamed buffer by its number", function()
    reset()
    host.cmd("setlocal bufhidden=hide")
    host.fn.setline(1, { "a", "b" })
    local bufnr = host.fn.bufnr("%")
    host.cmd("silent! enew!")
    local action = builtin.action.open({ opener = "split" })
    t.invoke(action, { item = t.item("x", { bufnr = bufnr, bufname = "", line = 2 }) })
    t.eq(host.fn.winnr("$"), 2)
    t.eq(host.fn.bufnr("%"), bufnr)
    t.eq(host.fn.line("."), 2)
  end)
end)

t.describe("builtin.action.default_open_actions", function()
  t.it("holds open and its split variants", function()
    local names = {}
    for name, action in pairs(builtin.action.default_open_actions) do
      t.ok(type(action.invoke) == "function")
      names[#names + 1] = name
    end
    table.sort(names)
    t.eq(names, { "open", "open:drop", "open:split", "open:tabedit", "open:vsplit" })
  end)

  t.it("splits with open:vsplit", function()
    reset()
    local p = file()
    t.invoke(
      builtin.action.default_open_actions["open:vsplit"],
      { item = t.item("x", { path = p }) }
    )
    t.eq(host.fn.winnr("$"), 2)
    t.eq(current(), p)
  end)
end)
