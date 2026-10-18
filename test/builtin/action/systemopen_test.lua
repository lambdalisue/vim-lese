local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

t.describe("builtin.action.systemopen", function()
  t.it("passes each path to the command", function()
    if host.fn.has("win32") == 1 or host.fn.executable("sh") == 0 then
      return
    end
    local out = host.fn.tempname()
    local action = builtin.action.systemopen({
      command = { "sh", "-c", 'printf "%s\\n" "$1" >> "$0"', out },
    })
    t.invoke(action, {
      selected_items = { t.item("a", { path = "/a" }), t.item("b", { path = "/b" }) },
    })
    t.eq(host.fn.readfile(out), { "/a", "/b" })
  end)

  t.it("is in default_systemopen_actions", function()
    t.ok(builtin.action.default_systemopen_actions.systemopen.invoke)
  end)
end)
