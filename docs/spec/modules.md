# Modules

The format extension authors write. lese defines it, so it is specified in
full. Every type named here is declared in `lua/lese/types.lua`.

## Items

An item is a Lua table:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | any, not nil | Unique among the items one source emits. Selection is kept by id. |
| `value` | string | What matchers match against. |
| `detail` | table | Whatever the extension needs later (a path, a buffer number). |
| `label` | string, optional | What the list shows. Renderers set it; without one the list shows `value`. |
| `decorations` | list, optional | Highlighted byte ranges of the label. |

A decoration is `{ column = integer, length = integer, highlight = string? }`:
`column` is the 1-based byte column in the label, `length` is in bytes, and
`highlight` defaults to `LeseListMatch`. After rendering, every decoration
lies within the label.

A preview item is `{ content = string[], line?, column?, filetype?, filename? }`;
`line` and `column` are 1-based and put the cursor there.

## Modules

Each module is a table with a `name` (used in every error and warning) and one
function that takes `ctx` first. Define modules with `require("lese.define")`,
which checks the contract while strict mode is on.

| Module | Function | Hands back |
| --- | --- | --- |
| Source | `collect(ctx, { args })` | items through `ctx:emit()` |
| Curator | `curate(ctx, { args, query })` | items through `ctx:emit()`, once per query |
| Matcher | `match(ctx, { query, items })` | the matching items through `ctx:emit()` |
| Sorter | `sort(ctx, { items })` | `items` reordered in place |
| Renderer | `render(ctx, { items })` | `label` and `decorations` of `items` set in place |
| Previewer | `preview(ctx, { item })` | a preview item, or nil |
| Action | `invoke(ctx, { item, selected_items, filtered_items, query })` | `true` to keep the picker open |
| Refiner | `refine(ctx, item)` | the item, changed or not, or nil to drop it |
| Coordinator | `style(theme)`, `layout(screen)` | window borders and positions |

- A matcher never changes the items it receives; it emits copies when it adds
  decorations. A sorter and a renderer keep the number of items.
- A renderer receives copies of the visible items only, with `label` already
  set to `value` when it was unset.
- An action's `item` is the item under the cursor; `selected_items` is nil
  when nothing is selected.
- A matcher with `incremental = true` has its results shown while it runs.

Modules that take options are functions that return the module:
`builtin.source.file({ ... })`. They are always called, options or not.

## The context

| Member | Does |
| --- | --- |
| `ctx.host` | the editor (`lese.host`): `call`, `fn`, `cmd`, `eval`, `defer`, `spawn`, `echo`, … |
| `ctx.name` | the running module's name |
| `ctx:emit(item_or_items)` | hands an item, or a list of items, over |
| `ctx:checkpoint()` | yields when the time budget is used, and raises when the run was cancelled |
| `ctx:cancelled()` | true once the run was cancelled |
| `ctx:spawn(cmd, { cwd, env, on_stdout, on_stderr })` | runs a command and returns its exit status; output reaches the handlers line by line, inside the module, so they may emit |
| `ctx:await(start)` | waits until `start` calls the function it receives |
| `ctx:sleep(ms)` | waits without blocking the editor |

A module that loops over many items calls `ctx:checkpoint()` in the loop;
running long without one freezes the editor and is reported in strict mode. A
cancelled module unwinds from its next checkpoint; it does not need to clean up
what `ctx:spawn()` started.

Modules reach the editor only through `ctx.host`. It takes and returns plain
Lua values on both Neovim and Vim.

## custom.lua

`custom.lua` returns a function that receives the entrypoint:

| Entry | Does |
| --- | --- |
| `define_picker_from_source(name, source, params)` | declares a picker over a source; `params.matchers` is required |
| `define_picker_from_curator(name, curator, params)` | declares a picker whose curator searches for each query |
| `refine_setting({ coordinator?, theme? })` | sets what every picker uses unless it says otherwise |
| `refine_action_picker({ matchers?, coordinator? })` | sets how the action list looks |

`params` holds `actions` (a map from name to action), `default_action`,
and optionally `matchers`, `sorters`, `renderers`, `previewers`,
`coordinator` and `theme`. Picker names and action names do not start with
`@`; a picker name is declared once.

## Extensions

An extension is a plugin with its Lua under `lua/lese-<name>/`. It provides
modules, and optionally a function that defines its recommended pickers when
the user calls it from `custom.lua`. Loading the extension declares nothing.
An extension checks for what it needs from lese by feature
(`pcall(require, ...)`, the presence of a field), never by version.
