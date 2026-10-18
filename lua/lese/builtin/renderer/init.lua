---@class lese.builtin.Renderer
---Leaves the label as it is.
---@field noop fun(): lese.Renderer
---Puts a Nerd Fonts icon for `item.detail.path` before the label; needs a Nerd Font.
---@field nerdfont fun(): lese.Renderer
---Shows a path label as "file dir", with the directory dimmed, so file names line up.
---@field smart_path fun(): lese.Renderer
---Rewrites the absolute `item.detail.path` in the label relative to `base` (default: the current directory).
---@field relative_path fun(opts?: lese.builtin.renderer.RelativePathOptions): lese.Renderer
---Rewrites a relative `item.detail.path` in the label as an absolute path under `base` (default: the current directory).
---@field absolute_path fun(opts?: lese.builtin.renderer.AbsolutePathOptions): lese.Renderer
---Shows a help tag of another language as "tag@lang", with "@lang" dimmed.
---@field helptag fun(): lese.Renderer

---@type lese.builtin.Renderer
return require("lese.builtin.lazy")("lese.builtin.renderer", {})
