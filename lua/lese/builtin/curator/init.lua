---@class lese.builtin.Curator
---@field git_grep fun(): lese.Curator
---@field grep fun(opts?: lese.builtin.curator.GrepOptions): lese.Curator
---@field noop fun(): lese.Curator
---@field rg fun(opts?: lese.builtin.curator.RgOptions): lese.Curator

return require("lese.builtin.lazy")("lese.builtin.curator", {})
