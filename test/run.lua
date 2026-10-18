-- Runs the tests inside the host that loaded this file: every
-- test/**/*_test.lua in an editor, or the files given as arguments in a bare
-- Lua. Start it with `just test`.
local files = { ... }
require("lese.testing.runner").main({
  dirs = { "test" },
  files = #files > 0 and files or nil,
})
