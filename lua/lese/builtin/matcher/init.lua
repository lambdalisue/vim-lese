---@class lese.builtin.Matcher
---@field fzf fun(opts?: lese.builtin.matcher.FzfOptions): lese.Matcher
---@field substring fun(opts?: lese.builtin.matcher.SubstringOptions): lese.Matcher
---@field regexp fun(): lese.Matcher
---@field noop fun(): lese.Matcher

---@type lese.builtin.Matcher
return require("lese.builtin.lazy")("lese.builtin.matcher", {})
