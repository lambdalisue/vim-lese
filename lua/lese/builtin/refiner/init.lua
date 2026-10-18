---@class lese.builtin.Refiner
---@field absolute_path fun(opts?: lese.builtin.refiner.AbsolutePathOptions): lese.Refiner
---@field cwd fun(): lese.Refiner
---@field exists fun(): lese.Refiner
---@field noop fun(): lese.Refiner
---@field regexp fun(opts: lese.builtin.refiner.RegexpOptions): lese.Refiner
---@field relative_path fun(opts?: lese.builtin.refiner.RelativePathOptions): lese.Refiner

return require("lese.builtin.lazy")("lese.builtin.refiner", {})
