local define = require("lese.define")

---@class lese.builtin.action.SubmatchOptions
---@field actions? table<string, lese.Action> -- default: the picker's own
---@field default_action? string              -- default: the picker's own
---@field sorters? lese.Sorter[]              -- default: the picker's own
---@field renderers? lese.Renderer[]          -- default: the picker's own
---@field previewers? lese.Previewer[]        -- default: the picker's own
---@field coordinator? lese.Coordinator
---@field theme? lese.Theme                   -- default: the picker's own

---Open the same picker again over the selected items (or every filtered item)
---with other matchers. Cancelling it returns to the picker it came from.
---@param matchers lese.Matcher[]
---@param opts? lese.builtin.action.SubmatchOptions
---@return lese.Action
return function(matchers, opts)
  opts = opts or {}
  if type(matchers) ~= "table" or #matchers == 0 then
    error("lese: builtin.action.submatch() needs at least one matcher", 2)
  end
  return define.action({
    name = "builtin.action.submatch",
    invoke = function(_, params)
      -- lese.command hands the picker over under a key that is not part of the API.
      local picker = rawget(params, "_picker")
      if not picker then
        error("lese: builtin.action.submatch runs only from a picker opened by :Lese", 0)
      end
      local base = picker.definition
      local items = params.selected_items or params.filtered_items
      local source = require("lese.builtin.source.list")(items)
      local definition = {
        name = base.name,
        build = function()
          return { source = source, matchers = matchers }
        end,
        sorters = opts.sorters or base.sorters,
        renderers = opts.renderers or base.renderers,
        previewers = opts.previewers or base.previewers,
        actions = opts.actions or base.actions,
        default_action = opts.default_action or base.default_action,
        coordinator = opts.coordinator or base.coordinator,
        theme = opts.theme or base.theme,
      }
      return require("lese.command").start(definition, { save_session = false }) == true
    end,
  })
end
