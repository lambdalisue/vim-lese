local t = require("lese.testing")
local args = require("lese.core.args")

t.describe("args.parse", function()
  t.it("splits on spaces", function()
    t.eq(args.parse("file  lua test"), { "file", "lua", "test" })
  end)

  t.it("keeps quoted spaces", function()
    t.eq(args.parse('file -input="Hello world"'), { "file", "-input=Hello world" })
    t.eq(args.parse("file -input='test'"), { "file", "-input=test" })
  end)

  t.it("keeps a quote of the other kind and escaped characters", function()
    t.eq(args.parse([[-input="He said 'hi'" a\ b]]), { "-input=He said 'hi'", "a b" })
  end)

  t.it("runs an unclosed quote to the end", function()
    t.eq(args.parse('file -input="unclosed'), { "file", "-input=unclosed" })
  end)

  t.it("returns nothing for blank input", function()
    t.eq(args.parse("   "), {})
  end)
end)
