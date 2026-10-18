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

## Development

Enter the development shell with `nix develop` (or copy `.envrc.sample` to
`.envrc` and `direnv allow`), then:

```sh
just fmt   # format every source
just ci    # everything CI runs: format check, lint, tests on every host
```

The design lives in [docs/concept.md](docs/concept.md), the decisions behind it
in [docs/adr/](docs/adr/), and the behaviour it promises in
[docs/spec/](docs/spec/).

## License

MIT. See [LICENSE](LICENSE).
