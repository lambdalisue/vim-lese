---@class lese.builtin.Coordinator
---@field modern fun(opts?: lese.builtin.coordinator.Options): lese.Coordinator
---@field compact fun(opts?: lese.builtin.coordinator.Options): lese.Coordinator
---@field separate fun(opts?: lese.builtin.coordinator.Options): lese.Coordinator

---@type lese.builtin.Coordinator
return require("lese.builtin.lazy")("lese.builtin.coordinator", {})
