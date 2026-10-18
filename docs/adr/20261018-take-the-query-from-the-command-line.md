# Take the query from the command line

Status: Accepted

## Context

A picker needs a prompt that edits text the way users expect, on both hosts.
fall read the query with `input()` and mirrored the command line in a
floating window, and its users configured keys with `cnoremap`.

## Decision

lese reads the query through the editor's command line, as fall did. The
input window only mirrors what the command line holds.

## Alternatives considered

- An editable prompt buffer in a floating window. Vim's popups cannot take
  focus, so it would not work there, and keys would be configured
  differently on each host.

## Consequences

- Picker keys are command-line mappings, the same on both hosts and the same
  as in fall.
- The picker is modal while open, like `input()`.
