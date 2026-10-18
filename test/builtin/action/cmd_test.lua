local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

local function captured(action, params)
  host.cmd("let g:lese_cmd_values = []")
  t.invoke(action, params)
  return host.eval("g:lese_cmd_values")
end

t.describe("builtin.action.cmd", function()
  t.it("runs the template with {} replaced by each item's value", function()
    local action = builtin.action.cmd({
      immediate = true,
      template = "call add(g:lese_cmd_values, '{}')",
    })
    t.eq(captured(action, { item = t.item("a") }), { "a" })
    t.eq(
      captured(action, { item = t.item("a"), selected_items = t.items({ "b", "c" }) }),
      { "b", "c" }
    )
  end)

  t.it("takes the value from attr_getter and skips items it returns nil for", function()
    local action = builtin.action.cmd({
      immediate = true,
      template = "call add(g:lese_cmd_values, '{}')",
      attr_getter = function(item)
        return item.detail.name
      end,
    })
    local items = { t.item("a", { name = "x" }), t.item("b") }
    t.eq(captured(action, { selected_items = items }), { "x" })
  end)

  t.it("escapes the value with fnameescape", function()
    local action = builtin.action.cmd({
      immediate = true,
      template = "call add(g:lese_cmd_values, '{}')",
      fnameescape = true,
    })
    t.eq(captured(action, { item = t.item("a b") }), { host.fn.fnameescape("a b") })
  end)

  t.it("quotes the value with shellescape", function()
    local action = builtin.action.cmd({
      immediate = true,
      template = "call add(g:lese_cmd_values, {})",
      shellescape = true,
    })
    t.eq(captured(action, { item = t.item("a b") }), { "a b" })
  end)

  t.it("applies the restriction to each value", function()
    local dir = host.fn.fnamemodify(host.fn.tempname(), ":p")
    host.fn.mkdir(dir, "p")
    local file = dir .. "f.txt"
    host.fn.writefile({ "x" }, file)
    local missing = dir .. "missing"
    local function run(restriction)
      local action = builtin.action.cmd({
        immediate = true,
        template = "call add(g:lese_cmd_values, '{}')",
        restriction = restriction,
      })
      return captured(action, { selected_items = t.items({ file, dir, missing }) })
    end
    t.eq(run("file"), { file })
    t.eq(run("directory"), { dir })
    t.eq(run("directory-or-parent"), { host.fn.fnamemodify(file, ":h"), dir })
  end)

  t.it("keeps buffers that are loaded with the buffer restriction", function()
    host.cmd("silent! enew!")
    host.cmd("setlocal bufhidden=hide")
    local name = host.fn.tempname()
    host.cmd("silent file " .. host.fn.fnameescape(name))
    local action = builtin.action.cmd({
      immediate = true,
      template = "call add(g:lese_cmd_values, '{}')",
      restriction = "buffer",
    })
    t.eq(captured(action, { selected_items = t.items({ name, host.fn.tempname() }) }), { name })
  end)

  t.it("reports a command that fails instead of raising", function()
    local action = builtin.action.cmd({ immediate = true, template = "LeseNoSuchCommand {}" })
    local messages = {}
    -- A real Vim error would make Vim -es exit non-zero, so the host fails instead.
    local failing = setmetatable({
      cmd = function()
        error("E492: Not an editor command")
      end,
      echo = function(message)
        messages[#messages + 1] = message
      end,
    }, { __index = host })
    t.run("cmd", function(ctx)
      local c = setmetatable({ host = failing }, { __index = ctx })
      action.invoke(c, { item = t.item("a"), filtered_items = {}, query = "" })
    end)
    t.eq(#messages, 1)
    t.ok(messages[1]:find("LeseNoSuchCommand a", 1, true), messages[1])
  end)
end)

t.describe("builtin.action.default_cmd_actions", function()
  t.it("holds cmd", function()
    t.ok(builtin.action.default_cmd_actions.cmd.invoke)
  end)
end)
