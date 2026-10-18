# vim-lese

A fuzzy finder for Vim and Neovim, written in Lua; the successor of fall.

## How it is built

- **Test first.** Red → green → refactor. Write the failing test before the
  code that makes it pass.
- **Each layer holds one thing.** Put a fact in the one layer that owns it,
  and nowhere else.

  | Layer | Holds |
  | --- | --- |
  | `docs/concept.md` | what this is and for whom |
  | `docs/adr/` | one decision and why it was made |
  | `docs/spec/` | the behaviour users and other components can rely on |
  | `doc/lese.txt` | the user manual: commands, mappings, options, highlights |
  | Tests | the details that pin the behaviour down: rules, boundaries, tables |
  | Code | how it is done |
  | Commits | why a change was made |
  | Comments | why it is not done another way |

  Before writing, fixing or reviewing a record, read `docs/adr/README.md`;
  before writing, fixing or reviewing a spec, read `docs/spec/README.md`.
  Follow their writing order.
- **Dependencies are current.** Before adding or bumping one, look up its
  latest release in the registry. Do not copy a version from memory or from
  another repository.

## Rules of the code

- **Lua 5.1 subset.** No `goto`, `//`, bitwise operators, `utf8`, direct
  `table.unpack` (use `require("lese.core.compat").unpack`), `setfenv` or
  `_ENV`. `stylua.toml` and `vim.yml` make `just ci` fail on them.
- **Host APIs only in `lua/lese/host/`.** Everything else reaches the editor
  through `lese.host` (or `ctx.host` inside a module). `vim.api`, `vim.cmd`,
  `vim.uv`, `vim.loop`, `vim.command`, `vim.list` and friends fail selene
  outside that directory. `lua/lese/core/` does not touch the host at all:
  it runs on a bare `luajit`.
- **Modules never block.** A module that loops over many items calls
  `ctx:checkpoint()` in the loop. External commands go through `ctx:spawn()`.

## Writing an extension

An extension is a plugin whose Lua lives under `lua/lese-<name>/`; the
`lese.` namespace is reserved for this repository.

1. Define each module with `require("lese.define")` (`define.source`,
   `define.matcher`, …). It checks the contract at run time and needs a
   `name`.
2. Write a test with `require("lese.testing")`: `t.collect`, `t.match`,
   `t.sort`, `t.render`, `t.preview`, `t.invoke` run one module;
   `t.picker(...)` drives a whole picker headlessly and `:screen()` returns
   what it shows. The same test runs on Neovim and Vim.
3. Try it without opening the UI:

   ```sh
   bin/lese-run --host=both --rtp ./ --custom ./test/custom.lua <picker> --query "<q>"
   ```

   `--host=both` exits non-zero when Neovim and Vim print different results.
4. Done means `just ci` is green and `lese-run --host=both` shows no
   difference.

`plugins/lese/skills/lese-extension/SKILL.md` carries the same guide as a
Claude Code skill.

## Quality gate

Run `just ci` before reporting a change as done. CI runs the same recipe.

## Layout

| Path | What lives there |
| --- | --- |
| `plugin/` | load guard, commands, `<Plug>` mappings, highlights; thin Vim script |
| `autoload/` | the Vim script API (`lese#action()`) |
| `lua/lese/core/` | pure Lua: scheduler, context, pipeline, session |
| `lua/lese/host/` | every difference between Neovim and Vim |
| `lua/lese/ui/` | input, list, preview and help windows; the picker |
| `lua/lese/builtin/` | the modules lese ships |
| `lua/lese/testing/` | test runner, picker driver, headless CLI, snapshots |
| `bin/` | `lese-run`, the headless CLI |
| `test/` | `*_test.lua`, run on every host |
| `doc/` | the Vim help file |
| `docs/` | concept, ADRs, specs |
| `plugins/lese/` | the Claude Code plugin with the extension-authoring skill |

## Language

- README, docs and commit messages: English
- Code comments, log and error messages: English

## Commits

Scoped Commits:

```
<scope>: <description>

<why this change is needed>
```

- The scope names where the change is, from the table below. Several scopes
  are joined with `, `; a change across the whole tree uses `treewide`.
- The description starts in lower case, has no trailing period, and stays
  within 72 characters.
- The body explains why. The code shows how; the tests show what.
- A release commit is `release: vX.Y.Z`.
- A breaking change says so in the body and carries a `BREAKING CHANGE:`
  trailer.

| Scope | Covers |
| --- | --- |
| `plugin` | `plugin/`, `autoload/` |
| `core` | `lua/lese/core/` |
| `host` | `lua/lese/host/` |
| `ui` | `lua/lese/ui/` |
| `builtin` | `lua/lese/builtin/` |
| `testing` | `lua/lese/testing/`, `bin/` |
| `lua` | the rest of `lua/lese/` (`define`, `std`, `types`, custom loading) |
| `test` | `test/` |
| `doc` | `doc/` |
| `docs` | `README.md`, `docs/concept.md` |
| `adr` | `docs/adr/` |
| `spec` | `docs/spec/` |
| `claude` | `plugins/`, `.claude-plugin/` |
| `ci` | `.github/` |
| `nix` | `flake.nix`, `flake.lock` |
| `deps` | dependency updates |

Add a row when a new area appears.
