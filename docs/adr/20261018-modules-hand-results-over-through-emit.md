# Modules hand results over through emit

Status: Accepted

## Context

fall's sources and matchers returned async iterators. Lua has no async
iterator; a generator would be a coroutine the module author manages.

## Decision

Sources, curators and matchers hand their results over by calling
`ctx:emit()` with an item or a list of items, from code that runs straight
through. They return nothing.

## Alternatives considered

- Return an iterator function. The author would have to keep the walk's state
  between calls, and a walk over an external command's output does not fit
  that shape.
- Return the whole list. Nothing would be shown until the walk finished.

## Consequences

- The scheduler decides how emitted items are batched and when to show them.
- Composing modules means calling one inside another's context.
