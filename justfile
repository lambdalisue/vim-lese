# Run `nix develop` (or use direnv) first so every tool is on PATH.

set shell := ["bash", "-euo", "pipefail", "-c"]

# The hosts `just test` runs on, in order. `luajit` runs only test/core/, the
# host-free part, without an editor. CI on Windows narrows it to `nvim`.
hosts := env("HOSTS", "luajit nvim vim vim-luajit")

# List the recipes.
default:
    @just --list

# Format every source.
fmt:
    stylua .
    nix fmt flake.nix

# Check formatting without changing files.
fmt-check:
    stylua --check .

# Lint, and type-check the LuaCATS annotations.
lint:
    selene .
    lua-language-server --check . --checklevel=Warning --configpath "$PWD/.luarc.json"

# Run the tests on every host, or only those whose name contains FILTER.
test filter="":
    for host in {{hosts}}; do just test-on "$host" "{{filter}}"; done

# Run the tests on one host: luajit, nvim, vim or vim-luajit.
test-on host filter="":
    TEST_FILTER="{{filter}}" {{ if host == "luajit" { "luajit -e 'package.path = \"lua/?.lua;lua/?/init.lua;\" .. package.path' test/run.lua test/core/*_test.lua" } else if host == "nvim" { "nvim --headless --clean --cmd 'set rtp^=.' -c 'luafile test/run.lua' </dev/null" } else { host + " -Nu NONE -i NONE -es --cmd 'set rtp^=.' -c 'luafile test/run.lua' </dev/null" } }}

# Everything CI runs.
ci: fmt-check lint test

# Run the tests and write every snapshot they compare with anew.
snapshot filter="":
    LESE_UPDATE_SNAPSHOTS=1 just test "{{filter}}"

# Run a picker headlessly on Neovim and Vim and fail when they differ.
run *args:
    bin/lese-run --host=both {{args}}
