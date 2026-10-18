# Running pickers headlessly

lese promises extension authors, people and agents alike, a way to run a
picker and read what it shows without opening the editor's UI. Both the test
API and `bin/lese-run` print the same text.

## The screen text

The first line names the picker (with its arguments after `:`), the query and
the count of items let through over the count collected; `+` marks a
collection cut at its limit, and `(failed)` a stage that failed.

```
file > init  3/120
> lua/lese/[init].lua
  lua/lese/host/[init].lua
 *lua/lese/testing/[init].lua
```

Each row starts with two marks: `>` on the cursor row, `*` on a selected row.
The parts of the label a matcher highlighted are wrapped in brackets.
Highlights a renderer adds under its own group are not shown.

The text depends only on what the modules hand back, never on the host, so
the same picker prints the same text on Neovim and on Vim.

## lese-run

`bin/lese-run [--host=nvim|vim|both] [--rtp DIR]... [--custom FILE] <picker>
[ARG]...` loads the pickers of `FILE` (or the user's custom.lua), runs
`<picker>` with the arguments and prints the screen text. `--help` lists the
options: type a query, press picker keys, select rows, preview a row, invoke
an action, or print JSON instead.

- `--rtp DIR` puts an extension under development on `'runtimepath'`
  without installing it.
- `--host=both` runs the picker on Neovim and on Vim and exits with status 3
  when they print different text.
- Contracts are checked as in tests. A module that fails prints `error:`
  lines and makes the exit status non-zero.

## The test API

`require("lese.testing")` runs inside the editor that loads it, so a test
file runs unchanged on Neovim, on Vim with PUC Lua and on Vim with LuaJIT.
It provides `describe`, `it` and assertions, runs single modules
(`collect`, `curate`, `match`, `sort`, `render`, `preview`, `invoke`,
`refine`), drives a whole picker with `picker()`, and compares text with a
stored snapshot. Tests run in strict mode: every contract is checked.
