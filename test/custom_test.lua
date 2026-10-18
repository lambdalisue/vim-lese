local t = require("lese.testing")
local host = require("lese.host")
local custom = require("lese.custom")
local cli = require("lese.testing.cli")

t.describe("the default custom.lua", function()
  t.it("declares fall's default pickers", function()
    custom.load_function(dofile(custom.default_path()))
    t.eq(custom.names(), {
      "grep",
      "git-grep",
      "rg",
      "file",
      "file:all",
      "line",
      "buffer",
      "help",
      "quickfix",
      "oldfiles",
      "history",
    })
  end)

  t.it("finds the files of this repository by name", function()
    local output, ok = cli.run(cli.parse({ "file", "--query", "concept", "--limit", "5" }))
    t.ok(ok, output)
    t.ok(output:find("docs/[concept].md", 1, true) or output:find("[concept]", 1, true), output)
  end)
end)

t.describe("custom.lua", function()
  local function load(main)
    custom.load_function(main)
  end

  t.it("rejects a picker name that starts with @", function()
    t.raises(function()
      load(function(x)
        x.define_picker_from_source("@x", { name = "s", collect = function() end }, {})
      end)
    end, "must not start with '@'")
  end)

  t.it("rejects a picker declared twice", function()
    local builtin = require("lese.builtin")
    local params = {
      matchers = { builtin.matcher.fzf() },
      actions = { echo = builtin.action.echo() },
      default_action = "echo",
    }
    t.raises(function()
      load(function(x)
        x.define_picker_from_source("a", builtin.source.noop(), params)
        x.define_picker_from_source("a", builtin.source.noop(), params)
      end)
    end, "picker 'a' is already defined")
  end)

  t.it("rejects a default action that is not among the actions", function()
    local builtin = require("lese.builtin")
    t.raises(function()
      load(function(x)
        x.define_picker_from_source("a", builtin.source.noop(), {
          matchers = { builtin.matcher.fzf() },
          actions = { echo = builtin.action.echo() },
          default_action = "open",
        })
      end)
    end, "has no action 'open' to use as 'default_action'")
  end)

  t.it("keeps the pickers it had when a reload fails halfway", function()
    local builtin = require("lese.builtin")
    local function declare(x, name)
      x.define_picker_from_source(name, builtin.source.noop(), {
        matchers = { builtin.matcher.fzf() },
        actions = { echo = builtin.action.echo() },
        default_action = "echo",
      })
    end
    load(function(x)
      declare(x, "old")
    end)
    t.raises(function()
      load(function(x)
        declare(x, "new")
        error("broken halfway")
      end)
    end, "broken halfway")
    t.eq(custom.names(), { "old" })
  end)

  t.it("loads a module again after a reload that failed once it was loaded", function()
    local version = 1
    package.preload["lese_custom_test_ext"] = function()
      return { version = version }
    end
    t.raises(function()
      load(function()
        require("lese_custom_test_ext")
        error("broken after the require")
      end)
    end, "broken after the require")
    version = 2
    local seen
    custom.load({ reload = true, path = custom.default_path() })
    load(function()
      seen = require("lese_custom_test_ext").version
    end)
    t.eq(seen, 2)
    package.preload["lese_custom_test_ext"] = nil
    package.loaded["lese_custom_test_ext"] = nil
  end)

  t.it("hands a curator picker its arguments even when nothing is collected", function()
    local seen
    local curator = require("lese.define").curator({
      name = "test.curator",
      curate = function(_, params)
        seen = params.args
      end,
    })
    local _, matcher = custom.curator_pipeline(curator, { "/target" })
    t.match(matcher, { query = "q", items = {} })
    t.eq(seen, { "/target" })
  end)

  t.it("loads g:lese_custom_path and keeps it when a reload fails", function()
    local dir = host.fn.tempname()
    host.fn.mkdir(dir, "p")
    local path = dir .. "/custom.lua"
    host.fn.writefile({
      'local builtin = require("lese.builtin")',
      "return function(x)",
      '  x.define_picker_from_source("mine", builtin.source.noop(), {',
      "    matchers = { builtin.matcher.fzf() },",
      "    actions = { echo = builtin.action.echo() },",
      '    default_action = "echo",',
      "  })",
      "end",
    }, path)
    host.cmd("let g:lese_custom_path = " .. host.fn.string(path))
    custom.load({ reload = true })
    t.eq(custom.names(), { "mine" })
    host.fn.writefile({ "return 1" }, path)
    host.cmd("silent! messages clear")
    custom.load({ reload = true })
    t.eq(custom.names(), { "mine" })
    host.cmd("unlet g:lese_custom_path")
  end)
end)
