---@class lese.builtin.Sorter
---Orders items by comparing strings byte by byte (the value, or `key(item)`); `reverse` flips the order, ties keep theirs.
---@field lexical fun(opts?: lese.builtin.sorter.LexicalOptions): lese.Sorter
---Orders items by a number (the value, or `key(item)`); non-numbers go last, `reverse` flips the order, ties keep theirs.
---@field numerical fun(opts?: lese.builtin.sorter.NumericalOptions): lese.Sorter
---Keeps the order.
---@field noop fun(): lese.Sorter

---@type lese.builtin.Sorter
return require("lese.builtin.lazy")("lese.builtin.sorter", {})
