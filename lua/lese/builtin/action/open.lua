local define = require("lese.define")

---@class lese.builtin.action.OpenDetail
---@field path? string
---@field bufname? string
---@field bufnr? integer
---@field line? integer
---@field column? integer

---@class lese.builtin.action.OpenOptions
---@field bang? boolean    -- run the opener with !
---@field mods? string     -- command modifiers, e.g. "vertical" or "silent"
---@field cmdarg? string   -- ++opt and +cmd arguments
---@field opener? string   -- the command for the first item, default "edit"
---@field splitter? string -- the command for every further item, default: the opener

-- An unnamed buffer cannot be given to :edit and friends by name.
local BUFFER_OPENERS = {
  edit = "buffer",
  split = "sbuffer",
  new = "sbuffer",
  vsplit = "vertical sbuffer",
  vnew = "vertical sbuffer",
  tabedit = "tab sbuffer",
  tabnew = "tab sbuffer",
}

local function join(...)
  local parts = {}
  for _, part in ipairs({ ... }) do
    if part ~= "" then
      parts[#parts + 1] = part
    end
  end
  return table.concat(parts, " ")
end

---Opens `detail.bufname`, `detail.path` or `detail.bufnr` of each chosen item
---(the selected items, or the item under the cursor), at `detail.line` and
---`detail.column` when set.
---@param opts? lese.builtin.action.OpenOptions
---@return lese.Action
return function(opts)
  opts = opts or {}
  local bang = opts.bang and "!" or ""
  local mods = opts.mods or ""
  local cmdarg = opts.cmdarg or ""
  local opener = opts.opener or "edit"
  local splitter = opts.splitter or opener

  return define.action({
    name = "builtin.action.open",
    invoke = function(ctx, params)
      local host = ctx.host
      local fn = host.fn
      local current = opener
      for _, item in ipairs(params.selected_items or { params.item }) do
        ctx:checkpoint()
        local detail = item.detail
        local name = detail.bufname
        if name == nil or name == "" then
          name = detail.path
        end
        if (name == nil or name == "") and detail.bufnr then
          name = fn.bufname(detail.bufnr)
        end
        if name ~= nil and name ~= "" then
          host.cmd(join(mods, current .. bang, cmdarg, fn.fnameescape(name)))
        elseif detail.bufnr then
          local command = BUFFER_OPENERS[current] or "buffer"
          host.cmd(join(mods, command .. bang, tostring(detail.bufnr)))
        end
        current = splitter
        if detail.line or detail.column then
          fn.cursor(detail.line or 1, math.max(detail.column or 1, 1))
          host.cmd("silent! normal! zv")
        end
      end
    end,
  })
end
