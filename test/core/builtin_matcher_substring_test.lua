local t = require("lese.testing")
local substring = require("lese.builtin.matcher.substring")

local function match(query, values, opts)
  return t.match(substring(opts), { query = query, items = t.items(values) })
end

t.describe("builtin.matcher.substring", function()
  t.it("is named builtin.matcher.substring", function()
    t.eq(substring().name, "builtin.matcher.substring")
  end)

  t.it("emits every item unchanged for a blank query", function()
    local items = t.items({ "b", "a" })
    local found = t.match(substring(), { query = "  ", items = items })
    t.ok(found[1] == items[1] and found[2] == items[2])
  end)

  t.it("keeps the items that contain every term, in input order", function()
    t.eq(t.values(match("ab cd", { "cd-ab", "abcd", "ab", "a b c d" })), { "cd-ab", "abcd" })
  end)

  t.it("takes the query literally, not as a pattern", function()
    t.eq(t.values(match("a.c", { "abc", "a.c" })), { "a.c" })
  end)

  t.it("respects case by default", function()
    t.eq(t.values(match("ab", { "AB", "ab" })), { "ab" })
  end)

  t.it("ignores case with ignore_case", function()
    t.eq(t.values(match("Ab", { "AB", "ab" }, { ignore_case = true })), { "AB", "ab" })
  end)

  t.it("ignores case with smart_case while the query is lower case", function()
    t.eq(t.values(match("ab", { "AB", "ab" }, { smart_case = true })), { "AB", "ab" })
    t.eq(t.values(match("Ab", { "AB", "Ab" }, { smart_case = true })), { "Ab" })
  end)

  t.it("decorates every occurrence of every term by byte", function()
    local found = match("あ b", { "あbxあ" })
    t.eq(found[1].decorations, {
      { column = 1, length = 3 },
      { column = 4, length = 1 },
      { column = 6, length = 3 },
    })
  end)

  t.it("appends to existing decorations without modifying the input", function()
    local item = t.item("abc")
    item.decorations = { { column = 1, length = 1, highlight = "X" } }
    local found = t.match(substring(), { query = "c", items = { item } })
    t.eq(
      found[1].decorations,
      { { column = 1, length = 1, highlight = "X" }, { column = 3, length = 1 } }
    )
    t.eq(item.decorations, { { column = 1, length = 1, highlight = "X" } })
  end)
end)
