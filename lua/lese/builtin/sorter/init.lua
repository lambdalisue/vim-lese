---@class lese.builtin.Sorter
---@field lexical fun(opts?: lese.builtin.sorter.LexicalOptions): lese.Sorter
---@field numerical fun(opts?: lese.builtin.sorter.NumericalOptions): lese.Sorter
---@field noop fun(): lese.Sorter

---@type lese.builtin.Sorter
return require("lese.builtin.lazy")("lese.builtin.sorter", {})
