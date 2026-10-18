local t = require("lese.testing")
local host = require("lese.host")
local builtin = require("lese.builtin")

-- A query is text to search for, even when it looks like an option.
t.describe("curators with a query that starts with -", function()
  local function root()
    local dir = host.fn.fnamemodify(host.fn.tempname(), ":p"):gsub("[/\\]$", "")
    host.fn.mkdir(dir, "p")
    host.fn.writefile({ "x --version y" }, dir .. "/a.txt")
    return dir
  end

  for _, case in ipairs({ { "grep", "grep" }, { "rg", "rg" } }) do
    t.it("searches for the text with " .. case[1], function()
      if host.fn.executable(case[2]) == 0 then
        return
      end
      local dir = root()
      local items = t.curate(builtin.curator[case[1]](), { args = { dir }, query = "--version" })
      t.eq(#items, 1)
      t.ok(items[1].value:find("x %-%-version y$"), items[1].value)
    end)
  end
end)
