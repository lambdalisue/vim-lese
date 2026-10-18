---
name: lese-extension
description: Write, test and try an extension (source, curator, matcher, sorter, renderer, previewer, action, refiner) for lese, the Lua fuzzy finder for Vim and Neovim. Use when the user asks for a new lese picker, a lese module, or a vim-lese-* plugin, or to debug one.
---

# Writing a lese extension

lese runs the same Lua on Neovim and on Vim (+lua). An extension is an
ordinary plugin; you cannot open its UI, so you prove it works with tests and
`lese-run`, on both editors.

## Find lese

1. In a repository made from `lambdalisue/vim-lese-template`, lese is checked
   out by `just deps` and every command below runs through `just`.
2. Otherwise find a vim-lese checkout (`bin/lese-run` and `lua/lese/` at its
   root) and use its `bin/lese-run` and test runner directly.
3. Without either, tell the user to create the extension from
   `lambdalisue/vim-lese-template` and stop. Never install anything on their
   behalf.

## Rules

- Lua lives under `lua/lese-<name>/`; never add files under `lua/lese/`.
- Write only the Lua 5.1 subset: no `goto`, `//`, bitwise operators, `utf8`,
  or `table.unpack` (use `require("lese.core.compat").unpack`).
- Reach the editor only through `ctx.host` (`ctx.host.fn.getcwd()`,
  `ctx.host.cmd(...)`). Never touch `vim.api`, `vim.cmd`, `vim.fn`,
  `vim.uv`, `vim.loop`, `vim.command` or `vim.list`; selene rejects them.
- Define every module with `require("lese.define")` and give it a `name`
  like `"lese-<name>.source.log"`.
- Hand items over with `ctx:emit()`; every item has `id`, `value` (string)
  and `detail` (table).
- Call `ctx:checkpoint()` in every loop over many items. Run commands with
  `ctx:spawn(cmd, { on_stdout = function(line) ... end })`, never with
  `system()`.
- Modules that take options are functions returning the module; users always
  call them.
- Describe everything users can reach, for lua-language-server: a `---`
  line on every public function, class and `---@field`. Declare the table
  `require("lese-<name>")` returns as a class with a described field per
  module.
- Extensions add no picker by themselves. Offer
  `require("lese-<name>").define_pickers(x)` for users to call from their
  custom.lua.

The full format is in vim-lese's `docs/spec/modules.md`; the types are in
`lua/lese/types.lua`.

## Steps

1. Write the test first, in `test/<module>_test.lua`:

   ```lua
   local t = require("lese.testing")
   local log = require("lese-git.source.log")

   t.describe("lese-git.source.log", function()
     t.it("lists commits newest first", function()
       local items = t.collect(log(), { args = { "." } })
       t.ok(#items > 0)
     end)

     t.it("renders the picker as expected", function()
       t.snapshot(t.picker({ source = log() }):type("fix"):screen())
     end)
   end)
   ```

   `t.collect`, `t.curate`, `t.match`, `t.sort`, `t.render`, `t.preview`,
   `t.invoke` and `t.refine` run one module. `t.picker(params)` drives a
   whole picker: `:type(text)`, `:press("<C-n>")`, `:screen()`, `:items()`,
   `:preview()`, `:invoke(name)`.
2. Run it and see it fail: `just test`.
3. Implement until `just test` passes on every host.
4. Try the picker without the UI:

   ```sh
   just run <picker> --query "<query>"          # both editors, diffed
   bin/lese-run --host=both --rtp . --custom test/custom.lua <picker> --preview 1
   ```

   Read the output: `>` marks the cursor row, `*` a selected row, and
   brackets show what matched. `--host=both` fails when Neovim and Vim differ.
5. Update snapshots only when the change is intended: `just snapshot`, then
   read the diff.

## Done means

- `just ci` is green (format, selene, lua-language-server with no warning,
  tests on Neovim, Vim with PUC Lua and Vim with LuaJIT).
- `lese-run --host=both` prints the same result on both editors.
- The extension's README shows the custom.lua line that brings its pickers
  in.

## When something fails

Errors name the module, the item and the field, for example
`lese: source 'lese-git.source.log' emitted item #3: field 'value' must be a
string, got nil`. Fix exactly what it names. A warning that a module "ran
… ms without ctx:checkpoint()" means a loop needs a checkpoint.
