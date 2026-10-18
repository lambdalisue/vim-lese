# Refiners transform or drop one item at a time

Status: Accepted

## Context

fall's refiners transformed the whole stream of items. In practice almost
every refiner rewrote an item or dropped it, and each still had to be written
as a stream transformation.

## Decision

A refiner takes one item and returns it, changed or not, or `nil` to drop it.
Work that needs the whole stream is written as a source that wraps another.

## Alternatives considered

- Keep stream refiners. Every refiner would carry a loop and a checkpoint for
  what is usually a one-line change.

## Consequences

- Refiners cannot reorder, merge or add items.
- The refining source checkpoints for its refiners.
