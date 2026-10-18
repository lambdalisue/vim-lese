---@class lese.builtin.Action
---@field buffer fun(opts?: lese.builtin.action.BufferOptions): lese.Action
---@field cd fun(opts?: lese.builtin.action.CdOptions): lese.Action
---@field cmd fun(opts?: lese.builtin.action.CmdOptions): lese.Action
---@field echo fun(): lese.Action
---@field help fun(): lese.Action
---@field noop fun(): lese.Action
---@field open fun(opts?: lese.builtin.action.OpenOptions): lese.Action
---@field quickfix fun(opts?: lese.builtin.action.QuickfixOptions): lese.Action
---@field systemopen fun(opts?: lese.builtin.action.SystemopenOptions): lese.Action
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
