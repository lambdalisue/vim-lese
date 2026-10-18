# vim-lese

A fuzzy finder for Vim and Neovim, written in Lua; the successor of fall.

_lese_ (German, "LAY-zeh") is the grape harvest: picking the good ones out of
many, as fall's autumn turns to harvest.

```vim
:Lese file
:Lese -input=README file
:Lese grep TODO
:LeseResume
```

## Install

Neovim 0.10 or later, or Vim 9.1 or later built with `+lua`. Install
`lambdalisue/vim-lese` with any plugin manager.

## Usage

`:Lese {picker} [{args}]` opens a picker. Type to narrow the list, `<C-n>` /
`<C-p>` to move, `<CR>` to run the default action and `<Tab>` to choose
another. `<F1>` lists every key.

The pickers are declared in `custom.lua`; `:LeseCustom` opens it, creating it
from the defaults on first use. See `:help lese` for the full manual.

## Writing an extension

Start from [vim-lese-template](https://github.com/lambdalisue/vim-lese-template):
it carries the tests, lint and CI an extension needs. Run a picker without
opening the editor's UI, on Neovim and Vim at once:

```sh
bin/lese-run --host=both --rtp path/to/extension --custom custom.lua <picker> --query "<query>"
```

The module format is specified in [docs/spec/modules.md](docs/spec/modules.md).
Claude Code users can install the `lese` plugin from this repository for a
skill that writes extensions this way.

## Development

Enter the development shell with `nix develop` (or copy `.envrc.sample` to
`.envrc` and `direnv allow`), then:

```sh
just fmt       # format every source
just ci        # everything CI runs: format check, lint, tests on every host
just snapshot  # write the snapshots tests compare with anew
just run file --query init   # a picker on Neovim and Vim, diffed
```

The design lives in [docs/concept.md](docs/concept.md), the decisions behind it
in [docs/adr/](docs/adr/), and the behaviour it promises in
[docs/spec/](docs/spec/).

## License

MIT. See [LICENSE](LICENSE).
