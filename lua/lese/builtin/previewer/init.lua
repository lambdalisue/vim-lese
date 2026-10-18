---@class lese.builtin.Previewer
---Shows the buffer at `detail.bufnr`, loading it when needed, at `detail.line`/`detail.column`.
---@field buffer fun(): lese.Previewer
---Shows the file at `detail.preview_path` or `detail.path`, at `detail.line`/`detail.column`; `limit` and `max_bytes` cap what is read.
---@field file fun(opts?: lese.builtin.previewer.FileOptions): lese.Previewer
---Shows the help file that defines `detail.helptag`, at the tag.
---@field helptag fun(): lese.Previewer
---Shows nothing; a placeholder where a previewer is required.
---@field noop fun(): lese.Previewer

return require("lese.builtin.lazy")("lese.builtin.previewer", {})
