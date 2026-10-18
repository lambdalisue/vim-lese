local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

t.describe("builtin.previewer.buffer", function()
  t.it("shows the buffer at detail.bufnr with its name, filetype and position", function()
    host.cmd("silent! enew")
    host.cmd("setlocal bufhidden=hide filetype=lua")
    host.cmd("silent file " .. host.fn.fnameescape(host.fn.tempname() .. ".lua"))
    host.fn.setline(1, { "local a = 1", "return a" })
    local bufnr = host.fn.bufnr("%")
    host.cmd("silent! enew")
    local result =
      t.preview(builtin.previewer.buffer(), t.item("x", { bufnr = bufnr, line = 2, column = 1 }))
    t.eq(result, {
      content = { "local a = 1", "return a" },
      filename = host.fn.fnamemodify(host.fn.bufname(bufnr), ":t"),
      filetype = "lua",
      line = 2,
      column = 1,
    })
  end)

  t.it("shows nothing for a buffer that does not exist", function()
    t.eq(t.preview(builtin.previewer.buffer(), t.item("x", { bufnr = 99999 })), nil)
  end)
end)
