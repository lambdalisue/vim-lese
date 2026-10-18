-- The command runner behind builtin.action.cmd and the actions built on it
-- (buffer, cd, help), which differ only in their name and options.

local define = require("lese.define")

---@alias lese.builtin.action.CmdRestriction "file"|"directory"|"directory-or-parent"|"buffer"

---@class lese.builtin.action.CmdOptions
---@field attr_getter? fun(item: lese.Item): string? -- the value for {}, default: item.value; nil skips the item
---@field immediate? boolean    -- run without asking; otherwise the command is put on the command line to edit
---@field template? string      -- the command, with {} replaced by the value; default "{}"
---@field restriction? lese.builtin.action.CmdRestriction -- skip values that are not a file, a directory, ...
---@field fnameescape? boolean  -- escape the value with fnameescape()
---@field shellescape? boolean  -- escape the value with shellescape()

local function value_of(item)
  return item.value
end

local function restrict(fn, value, restriction)
  if restriction == "file" then
    return fn.filereadable(value) == 1 and value or nil
  elseif restriction == "directory" then
    return fn.isdirectory(value) == 1 and value or nil
  elseif restriction == "directory-or-parent" then
    if fn.isdirectory(value) == 1 then
      return value
    elseif fn.getftype(value) ~= "" then
      return fn.fnamemodify(value, ":h")
    end
    return nil
  elseif restriction == "buffer" then
    return fn.bufloaded(value) == 1 and value or nil
  end
  error(string.format("unknown restriction '%s'", tostring(restriction)), 0)
end

---@param name string
---@param opts? lese.builtin.action.CmdOptions
---@return lese.Action
return function(name, opts)
  opts = opts or {}
  local attr_getter = opts.attr_getter or value_of
  local template = opts.template or "{}"

  return define.action({
    name = name,
    invoke = function(ctx, params)
      local host = ctx.host
      local fn = host.fn
      for _, item in ipairs(params.selected_items or { params.item }) do
        ctx:checkpoint()
        local value = attr_getter(item)
        if value ~= nil and opts.restriction then
          value = restrict(fn, value, opts.restriction)
        end
        if value ~= nil then
          if opts.fnameescape then
            value = fn.fnameescape(value)
          end
          if opts.shellescape then
            value = fn.shellescape(value)
          end
          local command = template:gsub("{}", function()
            return value
          end)
          if not opts.immediate then
            command = fn.input(":", command, "command")
          end
          if command ~= "" then
            local ok, err = pcall(host.cmd, command)
            if not ok then
              host.echo(
                string.format("[lese] Failed to execute '%s': %s", command, tostring(err)),
                "WarningMsg"
              )
            end
          end
        end
      end
    end,
  })
end
