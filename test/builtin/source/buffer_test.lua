local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

local function buffer(name, opts)
  opts = opts or {}
  host.cmd("silent! enew")
  host.cmd("silent file " .. host.fn.fnameescape(name))
  if opts.modified then
    host.fn.setline(1, "changed")
  end
  local bufnr = host.fn.bufnr("%")
  if opts.unlisted then
    host.cmd("setlocal nobuflisted")
  end
  host.cmd("setlocal bufhidden=hide")
  return bufnr
end

local function find(items, bufnr)
  for _, item in ipairs(items) do
    if item.detail.bufnr == bufnr then
      return item
    end
  end
  return nil
end

t.describe("builtin.source.buffer", function()
  t.it("emits named buffers with their number and name", function()
    local bufnr = buffer(host.fn.tempname())
    local item = find(t.collect(builtin.source.buffer()), bufnr)
    t.ok(item, "the buffer is missing")
    ---@cast item -nil
    local name = host.fn.getbufinfo(bufnr)[1].name
    t.eq(item.value, name)
    t.eq(item.detail.bufname, name)
    t.eq(item.detail.bufinfo.bufnr, bufnr)
  end)

  t.it("leaves unnamed buffers out", function()
    host.cmd("silent! enew")
    local bufnr = host.fn.bufnr("%")
    t.eq(find(t.collect(builtin.source.buffer()), bufnr), nil)
  end)

  t.it("keeps only listed buffers with filter buflisted", function()
    local listed = buffer(host.fn.tempname())
    local unlisted = buffer(host.fn.tempname(), { unlisted = true })
    local items = t.collect(builtin.source.buffer({ filter = "buflisted" }))
    t.ok(find(items, listed))
    t.eq(find(items, unlisted), nil)
  end)

  t.it("keeps only modified buffers with filter bufmodified", function()
    local clean = buffer(host.fn.tempname())
    local modified = buffer(host.fn.tempname(), { modified = true })
    local items = t.collect(builtin.source.buffer({ filter = "bufmodified" }))
    t.ok(find(items, modified))
    t.eq(find(items, clean), nil)
  end)

  t.it("gives each item its own id", function()
    buffer(host.fn.tempname())
    buffer(host.fn.tempname())
    local ids = {}
    for _, item in ipairs(t.collect(builtin.source.buffer())) do
      t.ok(not ids[item.id])
      ids[item.id] = true
    end
  end)
end)
