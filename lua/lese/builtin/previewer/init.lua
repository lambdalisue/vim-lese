---@class lese.builtin.Previewer
---@field buffer fun(): lese.Previewer
---@field file fun(opts?: lese.builtin.previewer.FileOptions): lese.Previewer
---@field helptag fun(): lese.Previewer
---@field noop fun(): lese.Previewer

return require("lese.builtin.lazy")("lese.builtin.previewer", {})
