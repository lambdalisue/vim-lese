# Absorb host differences in lese.host alone

Status: Accepted

## Context

Vim's `if_lua` and Neovim's Lua look alike but differ underneath: Vim cannot
pass a plain Lua table to a Vim function, returns lists and dictionaries as
userdata, and has popups, jobs and text properties where Neovim has floating
windows, `vim.system` and extmarks. Extensions are written by people, and
agents, who test on one editor.

## Decision

Every difference between Neovim and Vim is handled in `lese.host`. No other
part of lese, and no extension, calls a host API directly; they use the
adapter, which takes and returns plain Lua values on both hosts.

## Alternatives considered

- Let each module branch on the host where it needs to. Every author would
  have to know both hosts, and a branch untested on one host breaks there.
- Support Neovim only. Vim support is what sets lese apart.

## Consequences

- A static check forbids host APIs outside the adapter, in lese and in
  extensions.
- Supporting a new host feature means growing the adapter first.
- `lese.core` touches no host at all and runs on a bare Lua interpreter.
