local t = require("lese.testing")
local theme = require("lese.builtin.theme")

-- A sample of a theme's borders and dividers, drawn as fall's tests do.
local function sample(th)
  local width, half, height = 22, 11, 5
  local b, d = th.border, th.divider
  local function at(x, y)
    if (x == 0 or x == half) and y == 0 then
      return b[1]
    elseif (x == half - 1 or x == width - 1) and y == 0 then
      return b[3]
    elseif (x == 0 or x == half) and y == height - 1 then
      return b[7]
    elseif (x == half - 1 or x == width - 1) and y == height - 1 then
      return b[5]
    elseif x == 0 and y == 2 then
      return d[1]
    elseif x == half - 1 and y == 2 then
      return d[3]
    elseif y == 2 and x > 0 and x < half - 1 then
      return d[2]
    elseif x == 16 and y == 0 then
      return d[4]
    elseif x == 16 and y == height - 1 then
      return d[6]
    elseif x == 16 then
      return d[5]
    elseif x == 0 or x == half then
      return b[8]
    elseif x == half - 1 or x == width - 1 then
      return b[4]
    elseif y == 0 then
      return b[2]
    elseif y == height - 1 then
      return b[6]
    end
    return " "
  end
  local rows = {}
  for y = 0, height - 1 do
    local row = {}
    for x = 0, width - 1 do
      row[#row + 1] = at(x, y)
    end
    rows[#rows + 1] = table.concat(row)
  end
  return rows
end

t.describe("builtin.theme", function()
  t.it("MODERN has rounded corners and dashed dividers", function()
    t.eq(sample(theme.MODERN), {
      "╭─────────╮╭────┬────╮",
      "│         ││    ╎    │",
      "├╌╌╌╌╌╌╌╌╌┤│    ╎    │",
      "│         ││    ╎    │",
      "╰─────────╯╰────┴────╯",
    })
  end)

  t.it("SINGLE has single lines", function()
    t.eq(sample(theme.SINGLE), {
      "┌─────────┐┌────┬────┐",
      "│         ││    │    │",
      "├─────────┤│    │    │",
      "│         ││    │    │",
      "└─────────┘└────┴────┘",
    })
  end)

  t.it("DOUBLE has double lines", function()
    t.eq(sample(theme.DOUBLE), {
      "╔═════════╗╔════╦════╗",
      "║         ║║    ║    ║",
      "╠═════════╣║    ║    ║",
      "║         ║║    ║    ║",
      "╚═════════╝╚════╩════╝",
    })
  end)

  t.it("ASCII uses ASCII characters only", function()
    t.eq(sample(theme.ASCII), {
      ".---------..---------.",
      "|         ||    :    |",
      "|~~~~~~~~~||    :    |",
      "|         ||    :    |",
      "'---------''---------'",
    })
    t.eq(theme.ASCII.spinner, { "-", "\\", "|", "/" })
    t.eq(theme.ASCII.head_symbol, ">")
    t.eq(theme.ASCII.fail_symbol, "X")
    t.eq({
      theme.ASCII.matcher_icon,
      theme.ASCII.sorter_icon,
      theme.ASCII.renderer_icon,
      theme.ASCII.previewer_icon,
    }, { "m:", "s:", "r:", "p:" })
  end)

  t.it("MODERN has Nerd Fonts icons for the modules", function()
    for _, field in ipairs({ "matcher_icon", "sorter_icon", "renderer_icon", "previewer_icon" }) do
      t.ok(type(theme.MODERN[field]) == "string" and #theme.MODERN[field] > 1, field)
    end
  end)
end)
