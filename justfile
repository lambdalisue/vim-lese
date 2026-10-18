# Run `nix develop` (or use direnv) first so every tool is on PATH.

set shell := ["bash", "-euo", "pipefail", "-c"]

# The hosts `just test` runs on. CI on Windows narrows it to `nvim`.
hosts := env("HOSTS", "nvim vim vim-luajit")

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

# Run the tests on one host: nvim, vim or vim-luajit.
test-on host filter="":
    TEST_FILTER="{{filter}}" {{ if host == "nvim" { "nvim --headless --clean" } else { host + " -Nu NONE -i NONE -es" } }} --cmd 'set rtp^=.' -c 'luafile test/run.lua' </dev/null

# Everything CI runs.
ci: fmt-check lint test
