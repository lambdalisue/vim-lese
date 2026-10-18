# Write in the Lua 5.1 subset both hosts share

Status: Accepted

## Context

Neovim embeds LuaJIT, which speaks Lua 5.1. Vim links whichever Lua it was
built with, from 5.1 to 5.5 or LuaJIT, and users cannot choose. lese runs on
both editors from one source tree.

## Decision

lese is written in the subset of Lua 5.1 that LuaJIT and every PUC Lua from
5.1 to 5.5 accept and run alike. Newer syntax and library functions are not
used; the few that differ in name are reached through a compatibility shim.

## Alternatives considered

- Target LuaJIT and Lua 5.4 separately with a build step. Plugins are
  installed from Git as they are, so there is no build step to run.
- Write for Lua 5.4 and require Vim built with it. Neovim would be left out.

## Consequences

- The formatter and the linter reject `goto`, integer division, bitwise
  operators and post-5.1 library calls.
- Tests run on LuaJIT and on the newest PUC Lua so a difference shows up.
