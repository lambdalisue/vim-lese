local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

local function buffer()
  host.cmd("silent! enew!")
  local name = host.fn.tempname()
  host.cmd("silent file " .. host.fn.fnameescape(name))
  host.cmd("setlocal bufhidden=hide")
  local bufnr = host.fn.bufnr("%")
  host.cmd("silent! enew!")
  return bufnr, name
end

t.describe("builtin.action.buffer", function()
  t.it("deletes the buffer named by detail.bufname by default", function()
    local bufnr, name = buffer()
    t.invoke(builtin.action.buffer(), { item = t.item("x", { bufname = name }) })
    t.eq(host.fn.buflisted(bufnr), 0)
  end)

  t.it("runs the command it was given on detail.path", function()
    local bufnr, name = buffer()
    t.invoke(
      builtin.action.buffer({ command = "bwipeout" }),
      { item = t.item("x", { path = name }) }
    )
    t.eq(host.fn.bufexists(bufnr), 0)
  end)

  t.it("writes a buffer with write", function()
    local bufnr, name = buffer()
    host.fn.setbufline(bufnr, 1, "written")
    t.invoke(
      builtin.action.buffer({ command = "write" }),
      { item = t.item("x", { bufname = name }) }
    )
    t.eq(host.fn.readfile(name), { "written" })
    t.eq(host.fn.tabpagenr("$"), 1)
  end)

  t.it("rejects an unknown command", function()
    t.raises(function()
      local opts = { command = "bogus" } ---@type any
      builtin.action.buffer(opts)
    end, "builtin.action.buffer: unknown command 'bogus'")
  end)
end)

t.describe("builtin.action.default_buffer_actions", function()
  t.it("holds bunload, bdelete, bwipeout and write", function()
    local names = {}
    for name in pairs(builtin.action.default_buffer_actions) do
      names[#names + 1] = name
    end
    table.sort(names)
    t.eq(names, { "bdelete", "bunload", "bwipeout", "write" })
  end)

  t.it("unloads with bunload", function()
    local bufnr, name = buffer()
    host.fn.bufload(bufnr)
    t.invoke(builtin.action.default_buffer_actions.bunload, { item = t.item("x", { path = name }) })
    t.eq(host.fn.bufloaded(bufnr), 0)
  end)
end)
