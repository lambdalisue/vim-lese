local t = require("lese.testing")
local host = require("lese.host")
local path = require("lese.builtin._path")
local builtin = require("lese.builtin")

local sep = path.separator(host)

local function file(lines, name)
  local dir = path.strip_trailing(host.fn.fnamemodify(host.fn.tempname(), ":p"))
  host.fn.mkdir(dir, "p")
  local p = path.join(dir, name or "sample.lua", sep)
  host.fn.writefile(lines, p)
  return p
end

t.describe("builtin.previewer.file", function()
  t.it("shows the file at detail.path with the cursor at detail.line and detail.column", function()
    local p = file({ "local a = 1", "return a" })
    local result =
      t.preview(builtin.previewer.file(), t.item("x", { path = p, line = 2, column = 3 }))
    t.eq(result, {
      content = { "local a = 1", "return a" },
      filename = "sample.lua",
      line = 2,
      column = 3,
    })
  end)

  t.it("prefers detail.preview_path", function()
    local shown = file({ "shown" })
    local result = t.preview(
      builtin.previewer.file(),
      t.item("x", { path = file({ "hidden" }), preview_path = shown })
    )
    ---@cast result -nil
    t.eq(result.content, { "shown" })
  end)

  t.it("resolves a relative path from the current directory", function()
    local p = file({ "relative" })
    local relative = host.fn.fnamemodify(p, ":.")
    local result = t.preview(builtin.previewer.file(), t.item("x", { path = relative }))
    ---@cast result -nil
    t.eq(result.content, { "relative" })
  end)

  t.it("reads at most limit lines, but always far enough to show detail.line", function()
    local lines = {}
    for i = 1, 20 do
      lines[i] = "line " .. i
    end
    local p = file(lines)
    local previewer = builtin.previewer.file({ limit = 3 })
    local top = t.preview(previewer, t.item("x", { path = p }))
    ---@cast top -nil
    t.eq(top.content, { "line 1", "line 2", "line 3" })
    local deep = t.preview(previewer, t.item("x", { path = p, line = 10 }))
    ---@cast deep -nil
    t.eq(deep.content[10], "line 10")
  end)

  t.it("shows a message instead of a binary file", function()
    local p = file({ "text", "nul\nbyte" }, "sample.bin")
    local result = t.preview(builtin.previewer.file(), t.item("x", { path = p }))
    t.eq(result, { content = { "No preview for binary file is available." } })
  end)

  t.it("shows a message instead of a file it cannot read", function()
    local p = host.fn.tempname()
    local result = t.preview(builtin.previewer.file(), t.item("x", { path = p }))
    ---@cast result -nil
    t.eq(#result.content, 1)
    t.ok(result.content[1]:find(p, 1, true), result.content[1])
  end)
end)
