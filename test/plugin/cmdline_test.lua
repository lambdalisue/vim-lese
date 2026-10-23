local t = require("lese.testing")
local host = require("lese.host")

-- input() needs a terminal, so the rule it leans on is tested on its own.
t.describe("lese#internal#cmdline#aborted", function()
  t.it("accepts a command line entered with <CR>", function()
    t.eq(host.call("lese#internal#cmdline#aborted", "\r"), 0)
  end)

  t.it("accepts a command line entered with <NL>", function()
    t.eq(host.call("lese#internal#cmdline#aborted", "\n"), 0)
  end)

  t.it("abandons a command line left with <Esc>", function()
    t.eq(host.call("lese#internal#cmdline#aborted", "\27"), 1)
  end)

  t.it("abandons a command line left with CTRL-C", function()
    t.eq(host.call("lese#internal#cmdline#aborted", "\3"), 1)
  end)
end)
