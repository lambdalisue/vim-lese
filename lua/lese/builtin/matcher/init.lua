---@class lese.builtin.Matcher
---fzf's extended search: space-separated fuzzy terms, `'` exact, `^` prefix, `$` suffix, `!` negation and `|` for OR; smart case unless `case_sensitive`/`ignore_case`, ordered by score unless `sort = false`.
---@field fzf fun(opts?: lese.builtin.matcher.FzfOptions): lese.Matcher
---Keeps the items that contain every space-separated term literally; case is respected unless `smart_case`/`ignore_case`.
---@field substring fun(opts?: lese.builtin.matcher.SubstringOptions): lese.Matcher
---Keeps the items a Vim regular expression matches; 'ignorecase' applies unless the pattern has `\c` or `\C`.
---@field regexp fun(): lese.Matcher
---Lets nothing through; a placeholder where a matcher is required.
---@field noop fun(): lese.Matcher

---@type lese.builtin.Matcher
return require("lese.builtin.lazy")("lese.builtin.matcher", {})
