# Match in pure Lua by default

Status: Accepted

## Context

Both hosts have `matchfuzzypos()`, a fuzzy matcher written in C. The default
matcher has to stay usable on a hundred thousand items on PUC Lua, the
slowest Lua Vim links. Measured on 100,000 paths on Vim 9.2:

| | LuaJIT | PUC Lua 5.5 |
| --- | --- | --- |
| fzf-style matching in Lua | 7–17 ms | 20–55 ms |
| `matchfuzzypos()` | 23–28 ms | 26–44 ms |
| converting the items to a Vim list | 18 ms | 22 ms |

## Decision

The default fuzzy matcher is written in Lua and runs under the scheduler like
any other module.

## Alternatives considered

- Call `matchfuzzypos()` on chunks of items. It was not faster on PUC Lua
  once the items are converted to a Vim list, slower on LuaJIT, and a single
  call cannot be cancelled midway.

## Consequences

- Matching behaves the same on both hosts and runs in the pure core tests.
- Matching a hundred thousand items takes several ticks on PUC Lua.
