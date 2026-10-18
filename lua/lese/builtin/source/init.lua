---@class lese.builtin.Source
---@field buffer fun(opts?: lese.builtin.source.BufferOptions): lese.Source
---@field file fun(opts?: lese.builtin.source.FileOptions): lese.Source
---@field helptag fun(): lese.Source
---@field history fun(opts?: lese.builtin.source.HistoryOptions): lese.Source
---@field line fun(opts?: lese.builtin.source.LineOptions): lese.Source
---@field list fun(items: lese.Item[]): lese.Source
---@field noop fun(): lese.Source
---@field oldfiles fun(): lese.Source
---@field quickfix fun(): lese.Source

return require("lese.builtin.lazy")("lese.builtin.source", {})
