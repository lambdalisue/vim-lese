local t = require("lese.testing")
local coordinator = require("lese.builtin.coordinator")
local theme = require("lese.builtin.theme")

local SCREEN = { width = 40, height = 15 }

-- Draw each window's border on a blank screen, as fall's tests do.
local function draw(c, screen)
  local style = c.style(theme.MODERN)
  local layout = c.layout(screen)
  local canvas = {}
  for y = 1, screen.height do
    canvas[y] = {}
    for x = 1, screen.width do
      canvas[y][x] = " "
    end
  end
  for _, part in ipairs({ "input", "list", "preview" }) do
    local border, d = style[part], layout[part]
    t.eq(border == nil, d == nil, part .. " has a style but no layout, or the other way")
    if border then
      local w, h = d.width, d.height
      for y = 0, h + 1 do
        for x = 0, w + 1 do
          local ch
          if y == 0 then
            ch = x == 0 and border[1] or x == w + 1 and border[3] or border[2]
          elseif y == h + 1 then
            ch = x == 0 and border[7] or x == w + 1 and border[5] or border[6]
          elseif x == 0 then
            ch = border[8]
          elseif x == w + 1 then
            ch = border[4]
          end
          if ch and ch ~= "" then
            canvas[d.row + y][d.col + x] = ch
          end
        end
      end
    end
  end
  local rows = {}
  for y, row in ipairs(canvas) do
    rows[y] = table.concat(row)
  end
  return rows
end

local BLANK = "                                        "

t.describe("builtin.coordinator.modern", function()
  t.it("is named builtin.coordinator.modern", function()
    t.eq(coordinator.modern().name, "builtin.coordinator.modern")
  end)

  t.it("puts the input above the list and the preview beside them", function()
    local c = coordinator.modern({ width_ratio = 0.8, height_ratio = 0.8 })
    t.eq(draw(c, SCREEN), {
      BLANK,
      "    ╭───────────╮╭─────────────────╮    ",
      "    │           ││                 │    ",
      "    ├╌╌╌╌╌╌╌╌╌╌╌┤│                 │    ",
      "    │           ││                 │    ",
      "    │           ││                 │    ",
      "    │           ││                 │    ",
      "    │           ││                 │    ",
      "    │           ││                 │    ",
      "    │           ││                 │    ",
      "    │           ││                 │    ",
      "    │           ││                 │    ",
      "    ╰───────────╯╰─────────────────╯    ",
      BLANK,
      BLANK,
    })
  end)

  t.it("leaves the preview out with hide_preview", function()
    local c = coordinator.modern({ hide_preview = true, width_ratio = 0.8, height_ratio = 0.8 })
    t.eq(draw(c, SCREEN), {
      BLANK,
      "    ╭──────────────────────────────╮    ",
      "    │                              │    ",
      "    ├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    ╰──────────────────────────────╯    ",
      BLANK,
      BLANK,
    })
  end)

  t.it("takes 80% x 60% of the screen by default, within the bounds", function()
    local layout = coordinator.modern({ hide_preview = true }).layout({ width = 100, height = 50 })
    t.eq(layout.input, { row = 11, col = 11, width = 78, height = 1 })
    t.eq(layout.list, { row = 13, col = 11, width = 78, height = 26 })
    local small = coordinator.modern({ hide_preview = true }).layout({ width = 5, height = 3 })
    t.eq(small.input.width + 2, 10, "width_min")
    local large = coordinator.modern({ hide_preview = true }).layout({ width = 1000, height = 500 })
    t.eq(large.input.width + 2, 340, "width_max")
    t.eq(large.input.height + 1 + large.list.height + 2, 70, "height_max")
  end)
end)

t.describe("builtin.coordinator.compact", function()
  t.it("is named builtin.coordinator.compact", function()
    t.eq(coordinator.compact().name, "builtin.coordinator.compact")
  end)

  t.it("shares the borders between the windows", function()
    local c = coordinator.compact({ width_ratio = 0.8, height_ratio = 0.8 })
    t.eq(draw(c, SCREEN), {
      BLANK,
      "    ╭────────────┬─────────────────╮    ",
      "    │            ╎                 │    ",
      "    ├╌╌╌╌╌╌╌╌╌╌╌╌╎                 │    ",
      "    │            ╎                 │    ",
      "    │            ╎                 │    ",
      "    │            ╎                 │    ",
      "    │            ╎                 │    ",
      "    │            ╎                 │    ",
      "    │            ╎                 │    ",
      "    │            ╎                 │    ",
      "    │            ╎                 │    ",
      "    ╰────────────┴─────────────────╯    ",
      BLANK,
      BLANK,
    })
  end)

  t.it("leaves the preview out with hide_preview", function()
    local c = coordinator.compact({ hide_preview = true, width_ratio = 0.8, height_ratio = 0.8 })
    t.eq(draw(c, SCREEN), {
      BLANK,
      "    ╭──────────────────────────────╮    ",
      "    │                              │    ",
      "    ├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    ╰──────────────────────────────╯    ",
      BLANK,
      BLANK,
    })
  end)
end)

t.describe("builtin.coordinator.separate", function()
  t.it("is named builtin.coordinator.separate", function()
    t.eq(coordinator.separate().name, "builtin.coordinator.separate")
  end)

  t.it("gives every window its own border", function()
    local c = coordinator.separate({ width_ratio = 0.8, height_ratio = 0.8, preview_ratio = 0.5 })
    local layout = c.layout(SCREEN)
    t.eq(layout.input.width + 2, 16)
    t.eq(layout.list.width + 2, 16)
    t.eq(layout.preview.width + 2, 16)
    t.eq(layout.input.height + 2, 3)
    t.eq(layout.list.height + 2, 12 - 3)
    t.eq(layout.preview.height + 2, 12)
    t.eq(draw(c, SCREEN), {
      BLANK,
      "    ╭──────────────╮╭──────────────╮    ",
      "    │              ││              │    ",
      "    ╰──────────────╯│              │    ",
      "    ╭──────────────╮│              │    ",
      "    │              ││              │    ",
      "    │              ││              │    ",
      "    │              ││              │    ",
      "    │              ││              │    ",
      "    │              ││              │    ",
      "    │              ││              │    ",
      "    │              ││              │    ",
      "    ╰──────────────╯╰──────────────╯    ",
      BLANK,
      BLANK,
    })
  end)

  t.it("leaves the preview out with hide_preview", function()
    local c = coordinator.separate({ hide_preview = true, width_ratio = 0.8, height_ratio = 0.8 })
    t.eq(draw(c, SCREEN), {
      BLANK,
      "    ╭──────────────────────────────╮    ",
      "    │                              │    ",
      "    ╰──────────────────────────────╯    ",
      "    ╭──────────────────────────────╮    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    │                              │    ",
      "    ╰──────────────────────────────╯    ",
      BLANK,
      BLANK,
    })
  end)
end)
