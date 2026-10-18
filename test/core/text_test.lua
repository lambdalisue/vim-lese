local t = require("lese.testing")
local text = require("lese.core.text")

t.describe("text.width", function()
  t.it("counts ASCII as one cell each", function()
    t.eq(text.width("abc"), 3)
  end)

  t.it("counts CJK and fullwidth characters as two cells", function()
    t.eq(text.width("日本語"), 6)
    t.eq(text.width("ＡＢ"), 4)
  end)

  t.it("counts pictographic emoji as two cells", function()
    t.eq(text.width("🚀 "), 3)
  end)

  t.it("counts box drawing and Braille as one cell", function()
    t.eq(text.width("╭─⣾"), 3)
  end)

  t.it("ignores control characters", function()
    t.eq(text.width("a\tb"), 2)
  end)
end)

t.describe("text.fit", function()
  t.it("cuts to the width without splitting a character", function()
    t.eq(text.fit("日本語", 5), "日本")
  end)

  t.it("pads to the width when asked", function()
    t.eq(text.fit("ab", 4, true), "ab  ")
    t.eq(text.fit("日本語", 5, true), "日本 ")
  end)
end)

t.describe("text.chars", function()
  t.it("splits UTF-8 into characters with their widths", function()
    t.eq(text.chars("aあ"), { { "a", 1 }, { "あ", 2 } })
  end)

  t.it("treats an invalid byte as a character of its own", function()
    t.eq(#text.chars("a\255b"), 3)
  end)
end)
