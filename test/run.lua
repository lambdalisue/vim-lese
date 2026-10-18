-- Runs every test/**/*_test.lua inside the host that loaded this file. Start it
-- with `just test`.
require("lese.testing.runner").main({ dirs = { "test" } })
