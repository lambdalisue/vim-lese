# 🍇 vim-lese

[![CI](https://github.com/lambdalisue/vim-lese/actions/workflows/ci.yml/badge.svg)](https://github.com/lambdalisue/vim-lese/actions/workflows/ci.yml)
[![Neovim 0.10+](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=fff)](#install)
[![Vim 9.1+ with +lua](https://img.shields.io/badge/Vim-9.1%2B%20%2Blua-019733?logo=vim&logoColor=fff)](#install)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Vim Help](https://img.shields.io/badge/vim-%3Ah%20lese-orange.svg)](doc/lese.txt)

<div align="center">

![vim-lese's screencast](https://github.com/user-attachments/assets/7826d485-e1cf-46f3-9f4a-afef211d3c53)<br>
<sup>`:Lese file`, `:Lese rg` and `:Lese help` on Neovim with
[vim-glyph-palette](https://github.com/lambdalisue/vim-glyph-palette) (colors on
glyphs) and [Nightfox](https://github.com/EdenEast/nightfox.nvim)</sup>

</div>

A fuzzy finder for Vim and Neovim, written in Lua; the successor of
[fall](https://github.com/vim-fall/fall.vim).

_lese_ (German, "LAY-zeh") is the grape harvest: picking the good ones out of
many, as fall's autumn turns to harvest.

## Features

- **Nothing to install but the plugin.** Lese runs on the Lua built into the
  editor, so there is no external runtime to keep in step with it. The same
  code drives Neovim (LuaJIT) and Vim (`+lua`, PUC Lua or LuaJIT).
- **Typing never waits for the list.** Collecting, matching and sorting run as
  coroutines under a time budget, so a picker over a large tree keeps taking
  keys while it fills.
- **fzf-style fuzzy matching** in pure Lua, with the matched characters
  highlighted and a further keystroke narrowing the previous result instead of
  starting over.
- **Preview, then act.** A preview follows the cursor; `<Tab>` opens a picker of
  every action the item supports (open in a split, send to quickfix, yank,
  `cd`, …).
- **Everything is a module.** Sources, curators, matchers, sorters, renderers,
  previewers, actions and themes are plain Lua tables, combined per picker in
  one `custom.lua`.
- **Built to be extended safely.** Module contracts are checked strictly, and a
  headless runner shows what a picker does on Neovim and Vim side by side.

## Install

Neovim 0.10 or later, or Vim 9.1 or later built with `+lua`. Install
`lambdalisue/vim-lese` with any plugin manager, for example with
[vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'lambdalisue/vim-lese'
```

The default pickers draw file icons with the `nerdfont` renderer: use a
[Nerd Font](https://www.nerdfonts.com) in the terminal, or remove
`builtin.renderer.nerdfont()` from `custom.lua`. The `rg` picker needs
[ripgrep](https://github.com/BurntSushi/ripgrep).

## Usage

`:Lese {picker} [{args}]` opens a picker.

```vim
:Lese file              " files under the current directory
:Lese -input=README file
:Lese rg                " search as you type, with ripgrep
:Lese grep TODO
:Lese buffer
:Lese help
:LeseResume             " reopen the last picker where it left off
```

The default pickers are `file`, `file:all`, `grep`, `git-grep`, `rg`, `line`,
`buffer`, `oldfiles`, `quickfix`, `history` and `help`.

Inside a picker:

| Key                       | Does                                        |
| ------------------------- | ------------------------------------------- |
| `<C-n>` / `<C-p>`         | Move the cursor in the list                 |
| `<C-j>` / `<C-k>`         | Select the item and move                    |
| `<Up>` / `<Down>`         | Scroll the preview                          |
| `<CR>`                    | Run the default action                      |
| `<Tab>`                   | Choose another action                       |
| `<C-x>` / `<C-v>`         | Open in a split / vertical split            |
| `<F1>`                    | List every key                              |

Set `g:lese#disable_default_mappings` to define your own; `:help lese-mapping`
lists the `<Plug>` mappings.

## Customization

The pickers are declared in `custom.lua`. `:LeseCustom` opens it, creating it
from the defaults on first use, and lese reloads it when it is saved:

```lua
local builtin = require("lese.builtin")

---@param x lese.Entrypoint
return function(x)
  x.refine_setting({
    coordinator = builtin.coordinator.modern(),
    theme = builtin.theme.MODERN,
  })

  x.define_picker_from_source("help", builtin.source.helptag(), {
    matchers = { builtin.matcher.fzf() },
    previewers = { builtin.previewer.helptag() },
    actions = builtin.action.default_help_actions,
    default_action = "help",
  })
end
```

`:help lese-customization` covers the rest, including how to make
lua-language-server know these types.

## Writing an extension

Start from [vim-lese-template](https://github.com/lambdalisue/vim-lese-template):
it carries the tests, lint and CI an extension needs.
[vim-lese-mr](https://github.com/lambdalisue/vim-lese-mr) is a small extension
built from it. Run a picker without opening the editor's UI, on Neovim and Vim
at once:

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
