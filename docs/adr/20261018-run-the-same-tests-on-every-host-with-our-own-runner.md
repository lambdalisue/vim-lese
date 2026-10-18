# Run the same tests on every host with our own runner

Status: Accepted

## Context

The point of lese's Vim support is that it holds, and the point of its
testing API is that extension authors can check that themselves. busted,
mini.test and vusted run only on Neovim or outside any editor.

## Decision

lese ships its own test runner, which runs inside whichever editor loads it.
The same test files run on Neovim, on Vim with PUC Lua and on Vim with
LuaJIT, in lese and in every extension that uses `lese.testing`.

## Alternatives considered

- busted outside the editor with a stubbed host. The stub would be tested
  instead of the hosts.
- mini.test or vusted on Neovim. Vim would go untested.

## Consequences

- lese maintains the runner and its assertions.
- The headless picker driver and the snapshot helpers live in the same
  library, so extension tests need nothing else.
