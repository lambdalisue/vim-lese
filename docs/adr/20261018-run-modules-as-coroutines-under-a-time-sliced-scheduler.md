# Run modules as coroutines under a time-sliced scheduler

Status: Accepted

## Context

fall ran its modules in Deno, outside the editor. In lese they run in the
editor's own Lua, on the thread that handles input. Vim stops reading keys
while Lua runs, so a module that walks a hundred thousand items freezes the
editor unless it gives control back.

## Decision

Every module call runs in a coroutine owned by a scheduler. Modules yield at
checkpoints; the scheduler resumes them in ticks driven by the host's timers
and gives control back to the editor when a tick has used its time budget.
Cancelling a run makes the module's next checkpoint raise, unwinding it.

## Alternatives considered

- Run modules in a separate process or thread. Neither host offers a Lua
  thread that can call back into the editor, and a process means serialising
  every item, which is what leaving Deno was for.
- Process items in fixed-size chunks between timer callbacks. Every module
  would have to be written as a resumable state machine.

## Consequences

- Module code is written straight-line, calling `ctx:checkpoint()` in loops.
- A module that never checkpoints still freezes the editor; the contract
  checker warns about it.
