local t = require("lese.testing")
local helptag = require("lese.builtin.renderer.helptag")

t.describe("builtin.renderer.helptag", function()
  t.it("is named builtin.renderer.helptag", function()
    t.eq(helptag().name, "builtin.renderer.helptag")
  end)

  t.it("appends the language, dimmed, to the label", function()
    local item = t.item("lese", { helptag = "lese", lang = "ja" })
    item.decorations = { { column = 1, length = 2 } }
    local rendered = t.render(helptag(), { item })[1]
    t.eq(rendered.label, "lese@ja")
    t.eq(rendered.decorations, {
      { column = 1, length = 2 },
      { column = 5, length = 3, highlight = "Comment" },
    })
  end)

  t.it("leaves a tag without a language alone", function()
    local rendered = t.render(helptag(), { t.item("lese", { helptag = "lese" }) })[1]
    t.eq(rendered.label, "lese")
    t.eq(rendered.decorations, {})
  end)

  t.it("counts the value in bytes", function()
    local rendered = t.render(helptag(), { t.item("あ", { helptag = "あ", lang = "ja" }) })[1]
    t.eq(rendered.decorations, { { column = 4, length = 3, highlight = "Comment" } })
  end)
end)
