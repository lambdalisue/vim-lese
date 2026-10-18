local t = require("lese.testing")
local builtin = require("lese.builtin")

local function refine_all(refiner, values)
  local kept = {}
  for _, item in ipairs(t.items(values)) do
    local refined = t.refine(refiner, item)
    if refined then
      kept[#kept + 1] = refined.value
    end
  end
  return kept
end

t.describe("builtin.refiner.regexp", function()
  t.it("keeps values that match any of includes", function()
    local refiner = builtin.refiner.regexp({ includes = { "\\.lua$", "^README" } })
    t.eq(refine_all(refiner, { "a.lua", "b.txt", "README.md" }), { "a.lua", "README.md" })
  end)

  t.it("drops values that match any of excludes", function()
    local refiner = builtin.refiner.regexp({ excludes = { "_test\\.", "^\\." } })
    t.eq(refine_all(refiner, { "a.lua", "a_test.lua", ".git" }), { "a.lua" })
  end)

  t.it("applies both", function()
    local refiner = builtin.refiner.regexp({ includes = { "\\.lua$" }, excludes = { "_test" } })
    t.eq(refine_all(refiner, { "a.lua", "a_test.lua", "b.txt" }), { "a.lua" })
  end)

  t.it("uses Vim regular expressions", function()
    local refiner = builtin.refiner.regexp({ includes = { "\\v^(foo|bar)$" } })
    t.eq(refine_all(refiner, { "foo", "bar", "baz" }), { "foo", "bar" })
  end)

  t.it("needs includes or excludes", function()
    t.raises(function()
      builtin.refiner.regexp({})
    end, "builtin.refiner.regexp needs 'includes' or 'excludes'")
  end)
end)
