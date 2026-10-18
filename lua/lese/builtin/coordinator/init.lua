---@class lese.builtin.Coordinator
---The input above the list in one box, split by the divider, and the preview in its own box on the right; sized by `width_ratio`, `height_ratio`, `preview_ratio`, and `hide_preview` drops the preview.
---@field modern fun(opts?: lese.builtin.coordinator.Options): lese.Coordinator
---Like `modern`, but every window shares one box split by the dividers.
---@field compact fun(opts?: lese.builtin.coordinator.Options): lese.Coordinator
---Every window in a box of its own: the input, the list below it, and the preview on the right.
---@field separate fun(opts?: lese.builtin.coordinator.Options): lese.Coordinator

---@type lese.builtin.Coordinator
return require("lese.builtin.lazy")("lese.builtin.coordinator", {})
