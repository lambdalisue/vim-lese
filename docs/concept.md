# Concept

This document describes what lese is for and the ideas every design decision
rests on. It is rewritten in place as the concept evolves; decisions built on
it are recorded as ADRs.

## What it is

lese is a fuzzy finder for Vim and Neovim, written in Lua. It is the successor
of [fall](https://github.com/vim-fall/fall.vim), rebuilt without Denops (Deno):
the whole picker runs inside the editor's own Lua.

The name is the German word for a grape harvest (_Weinlese_), and the old sense
of _lesen_ is "to pick, to gather". It follows fall (autumn) as its harvest, and
picking candidates out of many is what a fuzzy finder does.

A picker is assembled from small modules, as in fall:

- a **Source** collects items, or a **Curator** collects them for each query;
- a **Matcher** narrows them down by the query;
- a **Sorter** orders them and a **Renderer** decides how they look;
- a **Previewer** shows the item under the cursor;
- an **Action** does something with the chosen items;
- a **Refiner** transforms or drops items one at a time on their way in;
- a **Coordinator** and a **Theme** lay the windows out and draw their borders.

Users declare the pickers they want in `custom.lua`. Extensions are ordinary
Vim/Neovim plugins that provide more modules.

## Who it is for

- fall users who want the same commands, keys, looks and configuration model
  without running Deno.
- Vim users. Most Lua pickers run on Neovim only; lese treats Vim built with
  `+lua` as a first-class host.
- Extension authors, and in particular AI agents writing extensions. lese ships
  the tools to write, test and try an extension without opening the UI.

## Principles

- **Both hosts, one Lua.** The same code runs on Neovim and on Vim built with
  `+lua`, in the Lua 5.1 subset that LuaJIT and every PUC Lua Vim links share.
  Every difference between the hosts is absorbed in one place, `lese.host`.
  Nothing else, extensions included, calls a host API directly.
- **A pure core.** `lese.core` holds the types, the pipeline, the scheduler and
  cancellation, and touches no host API, so it runs and is tested without an
  editor.
- **Never freeze the editor.** Modules run as coroutines under a scheduler that
  yields back to the editor within a small time budget. A module calls
  `ctx:checkpoint()` to give the scheduler a chance to pause or cancel it.
- **Guardrails come first.** An author must be able to run a picker headlessly,
  read its output as text, assert it in tests that run on both hosts, and get
  an error that names the module, the item and the field that broke a
  contract. Static checks stop host API misuse before it runs.
- **Usability is compatible with fall; code is not.** Commands, `<Plug>`
  mappings and default keys, highlight groups, autocmds and the shape of the
  configuration carry over with `Fall` renamed to `Lese`. Module code does not.
- **Only declared pickers exist.** Installing an extension adds nothing to the
  picker list; the user brings its pickers in from `custom.lua`.
- **Types where they help, contracts where they do not.** Public types are
  written as LuaCATS annotations for lua-language-server. What the type system
  cannot express is checked at run time.

## What it does not do

- Run Deno or any other runtime besides the editor's Lua.
- Support Neovim before 0.10 or Vim before 9.1, or Vim without `+lua`.
- Keep code compatibility with fall's TypeScript modules.
- Require external commands. `rg`, `fd` and friends are used when a module asks
  for them; the built-in modules work without them.
- Publish to LuaRocks or stamp a version into the source. A Git tag is the
  release.
