local t = require("lese.testing")
local fzf = require("lese.builtin.matcher.fzf")

local function match(query, values, opts)
  return t.match(fzf(opts), { query = query, items = t.items(values) })
end

local function decorations_of(query, value, opts)
  local found = match(query, { value }, opts)
  t.eq(#found, 1, "expected " .. value .. " to match " .. query)
  return found[1].decorations
end

t.describe("builtin.matcher.fzf", function()
  t.it("is named builtin.matcher.fzf", function()
    t.eq(fzf().name, "builtin.matcher.fzf")
  end)

  t.it("emits every item unchanged and in order for an empty query", function()
    local items = t.items({ "b", "a", "c" })
    local found = t.match(fzf(), { query = "", items = items })
    t.eq(#found, 3)
    for i, item in ipairs(items) do
      t.ok(found[i] == item, "item #" .. i .. " is not the same table")
    end
  end)

  t.it("treats a whitespace-only query as empty", function()
    t.eq(t.values(match("  \t ", { "b", "a" })), { "b", "a" })
  end)

  t.it("drops items that do not contain the query characters in order", function()
    t.eq(t.values(match("abc", { "abc", "acb", "a_b_c", "ab" })), { "abc", "a_b_c" })
  end)

  t.describe("scoring", function()
    t.it("ranks a match on word boundaries above a scattered one", function()
      t.eq(t.values(match("fb", { "afoobar", "foo_bar" })), { "foo_bar", "afoobar" })
    end)

    t.it("ranks consecutive characters above characters split by gaps", function()
      t.eq(t.values(match("abc", { "axbxc", "abc" })), { "abc", "axbxc" })
    end)

    t.it("ranks a camelCase hump above a letter inside a word", function()
      t.eq(t.values(match("b", { "fooxbar", "fooBar" })), { "fooBar", "fooxbar" })
    end)

    t.it("breaks a tie with the shorter trimmed value", function()
      t.eq(t.values(match("ab", { "ab_long", "  ab  ", "ab_x" })), { "  ab  ", "ab_x", "ab_long" })
    end)

    t.it("keeps the original order of items that tie on score and length", function()
      t.eq(t.values(match("a", { "a1", "a2", "a3" })), { "a1", "a2", "a3" })
    end)

    t.it("keeps the original order with sort = false", function()
      local found = match("fb", { "afoobar", "foo_bar" }, { sort = false })
      t.eq(t.values(found), { "afoobar", "foo_bar" })
    end)

    t.it("adds up the scores of every term", function()
      t.eq(t.values(match("a b", { "xaxb", "a_b" })), { "a_b", "xaxb" })
    end)
  end)

  t.describe("case", function()
    t.it("ignores case while the query is lower case", function()
      t.eq(t.values(match("foo", { "FOO", "foo", "Foo" })), { "FOO", "foo", "Foo" })
    end)

    t.it("respects case once the query has an upper-case letter", function()
      t.eq(t.values(match("Foo", { "FOO", "foo", "Foo" })), { "Foo" })
    end)

    t.it("decides the case of each term on its own", function()
      t.eq(t.values(match("Foo bar", { "Foo BAR", "foo bar" })), { "Foo BAR" })
    end)

    t.it("always respects case with case_sensitive", function()
      t.eq(t.values(match("foo", { "FOO", "foo" }, { case_sensitive = true })), { "foo" })
    end)

    t.it("always ignores case with ignore_case", function()
      t.eq(t.values(match("Foo", { "FOO", "foo" }, { ignore_case = true })), { "FOO", "foo" })
    end)
  end)

  t.describe("extended syntax", function()
    t.it("matches 'term as a substring", function()
      t.eq(t.values(match("'oba", { "foobar", "fooxbar" })), { "foobar" })
    end)

    t.it("matches ^term at the start, after leading spaces", function()
      t.eq(t.values(match("^foo", { "foobar", "afoo", "  foo" })), { "  foo", "foobar" })
    end)

    t.it("matches term$ at the end, before trailing spaces", function()
      t.eq(t.values(match("bar$", { "foobar", "barfoo", "bar  " })), { "bar  ", "foobar" })
    end)

    t.it("matches ^term$ against the whole trimmed value", function()
      t.eq(t.values(match("^foo$", { "foo", "foobar", " foo " })), { "foo", " foo " })
    end)

    t.it("drops items that contain !term", function()
      t.eq(t.values(match("!bar", { "foobar", "fooxbaz", "baz" })), { "baz", "fooxbaz" })
    end)

    t.it("drops items that start with !^term", function()
      t.eq(t.values(match("!^foo", { "foobar", "afoo" })), { "afoo" })
    end)

    t.it("drops items that end with !term$", function()
      t.eq(t.values(match("!bar$", { "foobar", "barfoo" })), { "barfoo" })
    end)

    t.it("drops items that fuzzy-match !'term", function()
      t.eq(t.values(match("!'fb", { "foobar", "fxxx", "bxf" })), { "bxf", "fxxx" })
    end)

    t.it("keeps items that match either side of |", function()
      t.eq(t.values(match("foo | bar", { "foo", "bar", "baz" })), { "foo", "bar" })
    end)

    t.it("requires every term that is not joined by |", function()
      t.eq(t.values(match("foo bar", { "foo", "bar", "foo bar" })), { "foo bar" })
    end)

    t.it("ignores a term that is only an operator", function()
      t.eq(t.values(match("! ^ '", { "b", "a" })), { "b", "a" })
    end)

    t.it("adds no decoration for a negated term", function()
      t.eq(decorations_of("!x", "abc"), {})
    end)
  end)

  t.describe("decorations", function()
    t.it("merges consecutive matched characters into one decoration", function()
      t.eq(decorations_of("foo", "xfoo"), { { column = 2, length = 3 } })
    end)

    t.it("decorates each run of matched characters", function()
      t.eq(decorations_of("ac", "abc"), { { column = 1, length = 1 }, { column = 3, length = 1 } })
    end)

    t.it("merges and orders the runs of every term", function()
      t.eq(decorations_of("c ab", "abc"), { { column = 1, length = 3 } })
    end)

    t.it("decorates the whole substring of an exact term", function()
      t.eq(decorations_of("'bc", "abcd"), { { column = 2, length = 2 } })
    end)

    t.it("decorates a boundary occurrence of an exact term over an earlier one", function()
      t.eq(decorations_of("'ab", "xab_ab"), { { column = 5, length = 2 } })
    end)

    t.it("appends to the decorations the item already has", function()
      local item = t.item("abc")
      item.decorations = { { column = 1, length = 3, highlight = "Special" } }
      local found = t.match(fzf(), { query = "b", items = { item } })
      t.eq(found[1].decorations, {
        { column = 1, length = 3, highlight = "Special" },
        { column = 2, length = 1 },
      })
    end)

    t.it("does not modify the input item", function()
      local item = t.item("abc", { path = "abc" })
      local decorations = { { column = 1, length = 1 } }
      item.decorations = decorations
      local found = t.match(fzf(), { query = "c", items = { item } })
      t.ok(found[1] ~= item, "the emitted item is the input item")
      t.ok(item.decorations == decorations)
      t.eq(decorations, { { column = 1, length = 1 } })
      t.ok(found[1].detail == item.detail, "detail is shared, not copied")
    end)
  end)

  t.describe("multibyte", function()
    t.it("matches whole characters and decorates them by byte", function()
      -- か あ き い: each is 3 bytes
      t.eq(
        decorations_of("あい", "かあきい"),
        { { column = 4, length = 3 }, { column = 10, length = 3 } }
      )
    end)

    t.it("counts a multibyte gap as characters, not bytes", function()
      t.eq(t.values(match("ab", { "aééb", "axxxb" })), { "aééb", "axxxb" })
    end)

    t.it("does not fold the case of non-ASCII letters", function()
      t.eq(t.values(match("é", { "É", "é" })), { "é" })
    end)
  end)

  t.it("matches 20k items quickly on LuaJIT", function()
    if not package.loaded.jit then
      return
    end
    local words = { "src", "lib", "test", "core", "util", "init", "picker", "matcher" }
    local values = {}
    for i = 1, 20000 do
      values[i] = words[i % #words + 1]
        .. "/"
        .. words[math.floor(i / #words) % #words + 1]
        .. "_"
        .. i
        .. ".lua"
    end
    local items = t.items(values)
    local started = os.clock()
    local found = t.match(fzf(), { query = "pkmt", items = items })
    local elapsed = os.clock() - started
    t.ok(#found > 0)
    t.ok(elapsed < 1, string.format("took %.3f s", elapsed))
  end)
end)

t.describe("builtin.matcher.fzf narrows", function()
  local narrows = require("lese.builtin").matcher.fzf().narrows
  local ok = assert(narrows, "fzf declares narrows")

  t.it("holds when the query lengthens a term or adds one", function()
    t.eq(ok("ab", "abc"), true)
    t.eq(ok("ab", "ab cd"), true)
    t.eq(ok("'ab", "'abc"), true)
    t.eq(ok("^ab", "^abc"), true)
    t.eq(ok("ab$", "ab$ c"), true)
    t.eq(ok("", "a"), true)
  end)

  t.it("does not hold when the query does not extend the previous one", function()
    t.eq(ok("abc", "ab"), false)
    t.eq(ok("ab", "xb"), false)
  end)

  t.it("does not hold for a lengthened negation, end anchor, or an OR", function()
    t.eq(ok("!ab", "!abc"), false)
    t.eq(ok("ab$", "ab$c"), false)
    t.eq(ok("ab", "ab | cd"), false)
  end)

  t.it("gives the same result on the last result as on every item", function()
    local matcher = require("lese.builtin").matcher.fzf()
    local words = { "init", "lua", "lese", "core", "picker", "test", "vim", "nvim", "LSP", "Lsp" }
    local items = {}
    local seed = 7
    for i = 1, 400 do
      local parts = {}
      for k = 1, 3 do
        seed = (seed * 75 + 74) % 65537
        parts[k] = words[seed % #words + 1]
      end
      items[i] = { id = i, value = table.concat(parts, "/"), detail = {} }
    end
    local previous, last = "", items
    for _, query in ipairs({ "l", "li", "lin", "lin ", "lin i", "lin in", "lin ini" }) do
      local full = t.match(matcher, { query = query, items = items })
      if matcher.narrows(previous, query) then
        local kept = {}
        for _, item in ipairs(last) do
          kept[item.id] = true
        end
        local subset = {}
        for _, item in ipairs(items) do
          if kept[item.id] then
            subset[#subset + 1] = item
          end
        end
        t.eq(t.values(t.match(matcher, { query = query, items = subset })), t.values(full), query)
      end
      previous, last = query, full
    end
  end)
end)
