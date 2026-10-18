-- The custom.lua lese uses until you write your own; :LeseCustom copies it to
-- g:lese_custom_path for you to edit.
--
-- Install https://github.com/BurntSushi/ripgrep to use 'builtin.curator.rg'
-- Install https://www.nerdfonts.com/ to use 'builtin.renderer.nerdfont'
-- Install https://github.com/thinca/vim-qfreplace to use 'Qfreplace'

local builtin = require("lese.builtin")
local std = require("lese.std")

local function merge(...)
  local out = {}
  for _, actions in ipairs({ ... }) do
    for name, action in pairs(actions) do
      out[name] = action
    end
  end
  return out
end

local path_actions = merge(
  builtin.action.default_open_actions,
  builtin.action.default_systemopen_actions,
  builtin.action.default_cd_actions
)

local quickfix_actions = merge(builtin.action.default_quickfix_actions, {
  ["quickfix:qfreplace"] = builtin.action.quickfix({ after = "Qfreplace" }),
})

local misc_actions = merge(
  builtin.action.default_echo_actions,
  builtin.action.default_yank_actions,
  builtin.action.default_submatch_actions
)

local EXCLUDED_FILES = {
  ".7z",
  ".DS_Store",
  ".avi",
  ".bmp",
  ".class",
  ".dll",
  ".dmg",
  ".doc",
  ".docx",
  ".dylib",
  ".ear",
  ".exe",
  ".fla",
  ".flac",
  ".flv",
  ".gif",
  ".ico",
  ".id_ed25519",
  ".id_rsa",
  ".iso",
  ".jar",
  ".jpeg",
  ".jpg",
  ".key",
  ".mkv",
  ".mov",
  ".mp3",
  ".mp4",
  ".mpeg",
  ".mpg",
  ".o",
  ".obj",
  ".ogg",
  ".pdf",
  ".png",
  ".ppt",
  ".pptx",
  ".rar",
  ".so",
  ".swf",
  ".tar.gz",
  ".war",
  ".wav",
  ".webm",
  ".wma",
  ".wmv",
  ".xls",
  ".xlsx",
  ".zip",
}

local EXCLUDED_DIRECTORIES = {
  "$RECYCLE.BIN",
  ".cache",
  ".git",
  ".hg",
  ".ssh",
  ".svn",
  "__pycache__", -- Python
  "build", -- C/C++
  "node_modules", -- Node.js
  "target", -- Rust
}

local function filter_file(path)
  for _, suffix in ipairs(EXCLUDED_FILES) do
    if path:sub(-#suffix) == suffix then
      return false
    end
  end
  return true
end

local function filter_directory(path)
  local name = path:match("([^/\\]+)[/\\]*$") or path
  for _, excluded in ipairs(EXCLUDED_DIRECTORIES) do
    if name == excluded then
      return false
    end
  end
  return true
end

local function sorters()
  return {
    builtin.sorter.noop(),
    builtin.sorter.lexical(),
    builtin.sorter.lexical({ reverse = true }),
  }
end

---@param x lese.Entrypoint
return function(x)
  x.refine_setting({
    coordinator = builtin.coordinator.modern(),
    theme = builtin.theme.MODERN,
  })

  for _, picker in ipairs({
    { "grep", builtin.curator.grep() },
    { "git-grep", builtin.curator.git_grep() },
    { "rg", builtin.curator.rg() },
  }) do
    x.define_picker_from_curator(
      picker[1],
      std.refine_curator(picker[2], builtin.refiner.relative_path()),
      {
        sorters = sorters(),
        renderers = { builtin.renderer.nerdfont(), builtin.renderer.noop() },
        previewers = { builtin.previewer.file() },
        actions = merge(path_actions, quickfix_actions, misc_actions),
        default_action = "open",
      }
    )
  end

  x.define_picker_from_source(
    "file",
    std.refine_source(
      builtin.source.file({ filter_file = filter_file, filter_directory = filter_directory }),
      builtin.refiner.relative_path()
    ),
    {
      matchers = { builtin.matcher.fzf() },
      sorters = sorters(),
      renderers = {
        std.compose_renderers(builtin.renderer.smart_path(), builtin.renderer.nerdfont()),
        builtin.renderer.nerdfont(),
        builtin.renderer.noop(),
      },
      previewers = { builtin.previewer.file() },
      actions = merge(path_actions, quickfix_actions, misc_actions),
      default_action = "open",
    }
  )

  x.define_picker_from_source(
    "file:all",
    std.refine_source(builtin.source.file(), builtin.refiner.relative_path()),
    {
      matchers = { builtin.matcher.fzf() },
      sorters = sorters(),
      renderers = {
        std.compose_renderers(builtin.renderer.smart_path(), builtin.renderer.nerdfont()),
        builtin.renderer.nerdfont(),
        builtin.renderer.noop(),
      },
      previewers = { builtin.previewer.file() },
      actions = merge(path_actions, quickfix_actions, misc_actions),
      default_action = "open",
    }
  )

  x.define_picker_from_source("line", builtin.source.line(), {
    matchers = { builtin.matcher.fzf() },
    previewers = { builtin.previewer.buffer() },
    actions = merge(
      quickfix_actions,
      misc_actions,
      builtin.action.default_open_actions,
      builtin.action.default_buffer_actions
    ),
    default_action = "open",
    coordinator = builtin.coordinator.modern({ hide_preview = true }),
  })

  x.define_picker_from_source("buffer", builtin.source.buffer({ filter = "bufloaded" }), {
    matchers = { builtin.matcher.fzf() },
    sorters = sorters(),
    previewers = { builtin.previewer.buffer() },
    actions = merge(
      quickfix_actions,
      misc_actions,
      builtin.action.default_open_actions,
      builtin.action.default_buffer_actions
    ),
    default_action = "open",
  })

  x.define_picker_from_source("help", builtin.source.helptag(), {
    matchers = { builtin.matcher.fzf() },
    sorters = sorters(),
    previewers = { builtin.previewer.helptag() },
    actions = merge(misc_actions, builtin.action.default_help_actions),
    default_action = "help",
  })

  x.define_picker_from_source("quickfix", builtin.source.quickfix(), {
    matchers = { builtin.matcher.fzf() },
    sorters = sorters(),
    previewers = { builtin.previewer.buffer() },
    actions = merge(builtin.action.default_open_actions, misc_actions),
    default_action = "open",
  })

  x.define_picker_from_source(
    "oldfiles",
    std.refine_source(
      builtin.source.oldfiles(),
      builtin.refiner.cwd(),
      builtin.refiner.exists(),
      builtin.refiner.relative_path()
    ),
    {
      matchers = { builtin.matcher.fzf() },
      sorters = sorters(),
      previewers = { builtin.previewer.file() },
      actions = merge(path_actions, quickfix_actions, misc_actions),
      default_action = "open",
    }
  )

  x.define_picker_from_source("history", builtin.source.history(), {
    matchers = { builtin.matcher.fzf() },
    sorters = sorters(),
    actions = merge({ cmd = builtin.action.cmd({ immediate = true }) }, misc_actions),
    default_action = "cmd",
  })
end
