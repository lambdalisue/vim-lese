---@class lese.builtin.Renderer
---@field noop fun(): lese.Renderer
---@field nerdfont fun(): lese.Renderer
---@field smart_path fun(): lese.Renderer
---@field relative_path fun(opts?: lese.builtin.renderer.RelativePathOptions): lese.Renderer
---@field absolute_path fun(opts?: lese.builtin.renderer.AbsolutePathOptions): lese.Renderer
---@field helptag fun(): lese.Renderer

---@type lese.builtin.Renderer
return require("lese.builtin.lazy")("lese.builtin.renderer", {})
