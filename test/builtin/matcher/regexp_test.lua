local t = require("lese.testing")
local regexp = require("lese.builtin.matcher.regexp")

local function match(query, values)
  return t.match(regexp(), { query = query, items = t.items(values) })
end

t.describe("builtin.matcher.regexp", function()
  t.it("is named builtin.matcher.regexp", function()
    t.eq(regexp().name, "builtin.matcher.regexp")
  end)

  t.it("emits every item unchanged for a blank query", function()
    t.eq(t.values(match(" ", { "b", "a" })), { "b", "a" })
  end)

  t.it("keeps the items the Vim regexp matches, in input order", function()
    t.eq(t.values(match([[\<foo\d\+]], { "foo1", "xfoo2", "foo", "a foo3" })), { "foo1", "a foo3" })
  end)

  t.it("decorates every match by byte", function()
    local found = match("あ.", { "あaxあb" })
    t.eq(found[1].decorations, { { column = 1, length = 4 }, { column = 6, length = 4 } })
  end)

  t.it("skips empty matches", function()
    local found = match("x*", { "abx" })
    t.eq(t.values(found), { "abx" })
    t.eq(found[1].decorations, { { column = 3, length = 1 } })
  end)

  t.it("appends to existing decorations without modifying the input", function()
    local item = t.item("abc")
    item.decorations = { { column = 1, length = 1 } }
    local found = t.match(regexp(), { query = "c", items = { item } })
    t.eq(found[1].decorations, { { column = 1, length = 1 }, { column = 3, length = 1 } })
    t.eq(item.decorations, { { column = 1, length = 1 } })
  end)

  t.it("emits nothing for a pattern Vim rejects", function()
    t.eq(match([[\(]], { "(" }), {})
  end)

  t.it("respects case with \\C", function()
    t.eq(t.values(match([[\CA]], { "a", "A" })), { "A" })
  end)
end)
