-- Run-time checks of what modules hand back. Each error names the module, the
-- item and the field, and says what the field should be, so the message alone
-- is enough to fix the module.

local M = {}

---When true, every module's input and output is checked. lese.testing turns it
---on; the plugin turns it on from `g:lese_strict`.
M.strict = false

---A module that runs this long without a checkpoint freezes the editor.
M.starve_ms = 50

---Called with a warning that is not an error (a module that never yields).
---@type fun(message: string)
M.warn = function(_) end

local function describe_value(value)
  if type(value) == "string" then
    return string.format("%q", value)
  end
  return type(value) == "table" and "a table" or tostring(value)
end

local function fail(kind, name, message)
  error(string.format("lese: %s '%s' %s", kind, name, message), 0)
end

local function check_decorations(kind, name, where, item)
  local decorations = item.decorations
  if decorations == nil then
    return
  end
  if type(decorations) ~= "table" then
    fail(
      kind,
      name,
      string.format(
        "%s: field 'decorations' must be a list, got %s",
        where,
        describe_value(decorations)
      )
    )
  end
  for i, d in ipairs(decorations) do
    if type(d) ~= "table" or type(d.column) ~= "number" or type(d.length) ~= "number" then
      fail(
        kind,
        name,
        string.format(
          "%s: decorations[%d] must be { column = integer, length = integer }",
          where,
          i
        )
      )
    end
    if d.column < 1 then
      fail(
        kind,
        name,
        string.format("%s: decorations[%d].column must be 1 or more, got %d", where, i, d.column)
      )
    end
    if d.length < 0 then
      fail(
        kind,
        name,
        string.format("%s: decorations[%d].length must be 0 or more, got %d", where, i, d.length)
      )
    end
    if d.highlight ~= nil and type(d.highlight) ~= "string" then
      fail(kind, name, string.format("%s: decorations[%d].highlight must be a string", where, i))
    end
  end
end

---Check an item a module produced.
---@param kind string   -- "source", "matcher", ...
---@param name string   -- the module's name
---@param where string  -- "emitted item #3"
---@param item any
function M.item(kind, name, where, item)
  if type(item) ~= "table" then
    fail(kind, name, string.format("%s must be a table, got %s", where, describe_value(item)))
  end
  if type(item.value) ~= "string" then
    fail(
      kind,
      name,
      string.format("%s: field 'value' must be a string, got %s", where, describe_value(item.value))
    )
  end
  if item.id == nil then
    fail(kind, name, string.format("%s (value %q): field 'id' must be set", where, item.value))
  end
  if type(item.detail) ~= "table" then
    fail(
      kind,
      name,
      string.format(
        "%s (value %q): field 'detail' must be a table, got %s",
        where,
        item.value,
        describe_value(item.detail)
      )
    )
  end
  if item.label ~= nil and type(item.label) ~= "string" then
    fail(
      kind,
      name,
      string.format("%s (value %q): field 'label' must be a string", where, item.value)
    )
  end
  check_decorations(kind, name, string.format("%s (value %q)", where, item.value), item)
end

---Check a rendered item: the label is set and each decoration lies within it.
---@param name string
---@param index integer
---@param item any
function M.rendered(name, index, item)
  local where = string.format("rendered item #%d", index)
  M.item("renderer", name, where, item)
  if type(item.label) ~= "string" then
    fail(
      "renderer",
      name,
      string.format("%s (value %q): field 'label' must be a string", where, item.value)
    )
  end
  for i, d in ipairs(item.decorations or {}) do
    if d.column + d.length - 1 > #item.label then
      fail(
        "renderer",
        name,
        string.format(
          "%s (value %q): decorations[%d] spans bytes %d-%d, past the end of the %d-byte label %q",
          where,
          item.value,
          i,
          d.column,
          d.column + d.length - 1,
          #item.label,
          item.label
        )
      )
    end
  end
end

---Check what a previewer returned.
---@param name string
---@param result any
function M.preview(name, result)
  if result == nil then
    return
  end
  if type(result) ~= "table" then
    fail("previewer", name, "must return a preview item or nil, got " .. describe_value(result))
  end
  if type(result.content) ~= "table" then
    fail(
      "previewer",
      name,
      "returned a preview item whose field 'content' is not a list of strings"
    )
  end
  for i, line in ipairs(result.content) do
    if type(line) ~= "string" then
      fail(
        "previewer",
        name,
        string.format("returned content[%d] that is %s, not a string", i, describe_value(line))
      )
    end
  end
  for _, field in ipairs({ "line", "column" }) do
    if result[field] ~= nil and type(result[field]) ~= "number" then
      fail("previewer", name, string.format("returned field '%s' that is not a number", field))
    end
  end
end

---Check that a module kept the number of items it was given.
---@param kind string
---@param name string
---@param before integer
---@param after integer
function M.count(kind, name, before, after)
  if before ~= after then
    fail(
      kind,
      name,
      string.format(
        "changed the number of items from %d to %d; it must only reorder or relabel them",
        before,
        after
      )
    )
  end
end

---Raise when a module definition misses a field.
---@param kind string
---@param def any
---@param fn_name string
function M.definition(kind, def, fn_name)
  if type(def) ~= "table" then
    error(string.format("lese: define.%s() takes a table, got %s", kind, describe_value(def)), 3)
  end
  if type(def.name) ~= "string" or def.name == "" then
    error(string.format("lese: define.%s() needs a 'name' string to report errors with", kind), 3)
  end
  if type(def[fn_name]) ~= "function" then
    error(string.format("lese: %s '%s' needs a '%s' function", kind, def.name, fn_name), 3)
  end
end

return M
