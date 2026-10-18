# Users declare their pickers in custom.lua

Status: Accepted

## Context

fall had users declare every picker in a `custom.ts` file, and only those
pickers existed. Users liked seeing their whole set of pickers in one place
and fall's users already think in that shape.

## Decision

The pickers a user can open are exactly those declared in their
`custom.lua`, a Lua file that receives an entrypoint to define pickers and
refine settings. lese creates it from its defaults on first use.

## Alternatives considered

- A `setup({...})` table. It cannot express a picker built by composing
  modules without becoming a second configuration language.

## Consequences

- Reloading the configuration reruns the file from scratch.
- There is no picker without a declaration, not even a built-in one.
