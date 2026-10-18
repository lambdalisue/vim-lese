local t = require("lese.testing")
local view = require("lese.ui.view")

local function input(state)
  local base = {
    query = "",
    cmdpos = 1,
    offset = 0,
    collected = 0,
    processed = 0,
    truncated = false,
    collecting = false,
    processing = false,
    spinner = "*",
  }
  for k, v in pairs(state) do
    base[k] = v
  end
  return base
end

t.describe("view.input", function()
  t.it("shows the head symbol, the query and the counter across the width", function()
    local frame =
      view.input(input({ query = "abc", cmdpos = 4, collected = 10, processed = 3 }), 20)
    t.eq(frame.lines, { "> abc" .. string.rep(" ", 10) .. " 3/10" })
  end)

  t.it("shows the spinner while processing and the fail symbol after a failure", function()
    t.eq(view.input(input({ processing = true }), 12).lines[1]:sub(1, 2), "* ")
    t.eq(view.input(input({ processing = "failed" }), 12).lines[1]:sub(1, 4), "✕ ")
  end)

  t.it("marks a truncated collection and shows collecting at the end", function()
    local line = view.input(
      input({ collected = 5, processed = 5, truncated = true, collecting = true }),
      20
    ).lines[1]
    t.ok(line:find(" 5/5%+ %*$"), line)
  end)

  t.it("puts the cursor decoration on the character under the cursor", function()
    local frame = view.input(input({ query = "abc", cmdpos = 2 }), 20)
    t.eq(frame.decorations[2], { line = 1, column = 4, length = 1, highlight = "LeseInputCursor" })
  end)

  t.it("scrolls a long query to keep the cursor in view", function()
    local frame, offset =
      view.input(input({ query = string.rep("x", 30) .. "END", cmdpos = 34 }), 20)
    t.ok(offset > 0)
    t.ok(frame.lines[1]:find("END", 1, true), frame.lines[1])
  end)
end)

t.describe("view.list", function()
  t.it("shows labels and keeps decorations inside them", function()
    local frame = view.list({
      {
        id = 1,
        value = "a",
        label = "abc",
        detail = {},
        decorations = { { column = 2, length = 5 } },
      },
    })
    t.eq(frame.lines, { "abc" })
    t.eq(frame.decorations, { { line = 1, column = 2, length = 2, highlight = "LeseListMatch" } })
  end)

  t.it("replaces line breaks in labels", function()
    t.eq(view.list({ { id = 1, value = "a\nb", detail = {} } }).lines, { "a b" })
  end)
end)

t.describe("view.help_pages", function()
  t.it("lists only the mappings that reach lese", function()
    local pages = view.help_pages({
      { lhs = "<C-n>", rhs = "<Plug>(lese-list-next)" },
      { lhs = "<C-x>", rhs = "<Cmd>call lese#action('open:split')<CR>" },
      { lhs = "<C-a>", rhs = "<Home>" },
    }, 80, 10)
    t.eq(#pages, 1)
    local all = table.concat(pages[1].lines, "\n")
    t.ok(all:find("<C-x> ➙ action(open:split)", 1, true), all)
    t.ok(all:find("<C-n> ➙ list-next", 1, true), all)
    t.ok(not all:find("<C-a>", 1, true), all)
  end)

  t.it("says so when no mapping reaches lese", function()
    t.eq(view.help_pages({}, 80, 10)[1].lines, { "No mapping reaches lese." })
  end)
end)
