---@class lese.builtin.Curator
---Runs `git grep` in the current directory for each query.
---@field git_grep fun(): lese.Curator
---Runs `grep -r` on the directory in `args[1]` (default: the current directory) for each query.
---@field grep fun(opts?: lese.builtin.curator.GrepOptions): lese.Curator
---Emits nothing; a placeholder where a curator is required.
---@field noop fun(): lese.Curator
---Runs `rg` (ripgrep) on the directory in `args[1]` (default: the current directory) for each query; the options map to rg's flags.
---@field rg fun(opts?: lese.builtin.curator.RgOptions): lese.Curator

return require("lese.builtin.lazy")("lese.builtin.curator", {})
