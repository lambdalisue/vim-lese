# Installing an extension adds no pickers by itself

Status: Accepted

## Context

Extensions are plugins, and plugin managers load every installed plugin. If
loading an extension registered pickers, the picker list would depend on
what happens to be installed and in which order it loads.

## Decision

An extension only provides modules, and optionally a function that defines
its recommended pickers. The user calls it from `custom.lua`; nothing is
registered when the extension loads.

## Alternatives considered

- Register pickers on load, with an option to opt out. Names would collide
  between extensions with no one to resolve them.

## Consequences

- `custom.lua` stays the complete list of pickers.
- An extension's README has to show the line that brings its pickers in.
