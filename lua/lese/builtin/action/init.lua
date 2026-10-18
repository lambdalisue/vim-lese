---@class lese.builtin.Action
---Runs a buffer `command` (default "bdelete") on the buffer of each chosen item; see `default_buffer_actions`.
---@field buffer fun(opts?: lese.builtin.action.BufferOptions): lese.Action
---Changes the directory (`command`: "cd", "lcd" or "tcd") to `detail.path` or `detail.bufname`, or its parent for a file; see `default_cd_actions`.
---@field cd fun(opts?: lese.builtin.action.CdOptions): lese.Action
---Runs an Ex command built from `template` ("{}" is the value) for each chosen item, or puts it on the command line unless `immediate`.
---@field cmd fun(opts?: lese.builtin.action.CmdOptions): lese.Action
---Shows the chosen items in the message history.
---@field echo fun(): lese.Action
---Opens help at `detail.helptag`, in `detail.lang` when set.
---@field help fun(): lese.Action
---Does nothing; a placeholder where an action is required.
---@field noop fun(): lese.Action
---Opens `detail.bufname`, `detail.path` or `detail.bufnr` of each chosen item at `detail.line`/`detail.column`, with `opener` (default "edit"); see `default_open_actions`.
---@field open fun(opts?: lese.builtin.action.OpenOptions): lese.Action
---Puts the selected items, or every filtered item, in the quickfix list; `after` runs a command such as "copen" afterwards.
---@field quickfix fun(opts?: lese.builtin.action.QuickfixOptions): lese.Action
---Opens `detail.path` of each chosen item with the system's default application.
---@field systemopen fun(opts?: lese.builtin.action.SystemopenOptions): lese.Action
---Puts the values of the chosen items, one per line, in `v:register`.
---@field yank fun(): lese.Action
---@field default_open_actions table<string, lese.Action>       -- open, open:split, open:vsplit, open:tabedit, open:drop
---@field default_systemopen_actions table<string, lese.Action> -- systemopen
---@field default_cd_actions table<string, lese.Action>         -- cd, lcd, tcd
---@field default_quickfix_actions table<string, lese.Action>   -- quickfix, quickfix:copen
---@field default_echo_actions table<string, lese.Action>       -- echo
---@field default_yank_actions table<string, lese.Action>       -- yank
---@field default_buffer_actions table<string, lese.Action>     -- bunload, bdelete, bwipeout, write
---@field default_help_actions table<string, lese.Action>       -- help
---@field default_cmd_actions table<string, lese.Action>        -- cmd
---@field default_noop_actions table<string, lese.Action>       -- noop
---Opens the same picker again over the selected items (or every filtered item) with other `matchers`; cancelling it returns to the picker it came from.
---@field submatch fun(matchers: lese.Matcher[], opts?: lese.builtin.action.SubmatchOptions): lese.Action
---@field default_submatch_actions table<string, lese.Action>   -- sub:fzf, sub:substring, sub:regexp

local M = require("lese.builtin.lazy")("lese.builtin.action", {})

-- Each set is built on first access, so naming one loads only its actions.
local DEFAULTS = {
  default_open_actions = function()
    return {
      open = M.open(),
      ["open:split"] = M.open({ opener = "split" }),
      ["open:vsplit"] = M.open({ opener = "vsplit" }),
      ["open:tabedit"] = M.open({ opener = "tabedit" }),
      ["open:drop"] = M.open({ opener = "drop" }),
    }
  end,
  default_systemopen_actions = function()
    return { systemopen = M.systemopen() }
  end,
  default_cd_actions = function()
    return {
      cd = M.cd(),
      lcd = M.cd({ command = "lcd" }),
      tcd = M.cd({ command = "tcd" }),
    }
  end,
  default_quickfix_actions = function()
    return {
      quickfix = M.quickfix({ continue = true }),
      ["quickfix:copen"] = M.quickfix({ after = "copen" }),
    }
  end,
  default_echo_actions = function()
    return { echo = M.echo() }
  end,
  default_yank_actions = function()
    return { yank = M.yank() }
  end,
  default_buffer_actions = function()
    return {
      bunload = M.buffer({ command = "bunload" }),
      bdelete = M.buffer({ command = "bdelete" }),
      bwipeout = M.buffer({ command = "bwipeout" }),
      write = M.buffer({ command = "write" }),
    }
  end,
  default_help_actions = function()
    return { help = M.help() }
  end,
  default_cmd_actions = function()
    return { cmd = M.cmd() }
  end,
  default_noop_actions = function()
    return { noop = M.noop() }
  end,
  default_submatch_actions = function()
    local matcher = require("lese.builtin").matcher
    return {
      ["sub:fzf"] = M.submatch({ matcher.fzf() }),
      ["sub:substring"] = M.submatch({ matcher.substring() }),
      ["sub:regexp"] = M.submatch({ matcher.regexp() }),
    }
  end,
}

local load_module = getmetatable(M).__index

return setmetatable(M, {
  __index = function(t, name)
    local build = DEFAULTS[name]
    if build then
      local set = build()
      rawset(t, name, set)
      return set
    end
    return load_module(t, name)
  end,
})
