---@class lese.builtin.Refiner
---Replaces `detail.path` in the value with its absolute path under `base`, kept in `detail.abspath`.
---@field absolute_path fun(opts?: lese.builtin.refiner.AbsolutePathOptions): lese.Refiner
---Keeps the items whose `detail.path` is under the current directory.
---@field cwd fun(): lese.Refiner
---Keeps the items whose `detail.path` is a file or directory that exists.
---@field exists fun(): lese.Refiner
---Passes every item through unchanged.
---@field noop fun(): lese.Refiner
---Keeps values that match any of `includes` and drops those that match any of `excludes` (Vim regular expressions).
---@field regexp fun(opts: lese.builtin.refiner.RegexpOptions): lese.Refiner
---Replaces `detail.path` in the value with its path relative to `base`, kept in `detail.relpath`.
---@field relative_path fun(opts?: lese.builtin.refiner.RelativePathOptions): lese.Refiner

return require("lese.builtin.lazy")("lese.builtin.refiner", {})
