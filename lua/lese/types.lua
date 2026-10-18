---@meta
-- Every public type of lese, for lua-language-server. Extensions get these by
-- adding lese to `workspace.library`. Nothing here runs.

---A highlighted range in an item's label.
---@class lese.Decoration
---@field column integer      -- 1-based byte column in the label
---@field length integer      -- length in bytes
---@field highlight? string   -- default: LeseListMatch

---One candidate. `detail` holds whatever the extension needs; declare its
---shape with your own `---@class`.
---@class lese.Item
---@field id any                           -- unique within a source
---@field value string                     -- what matchers match against
---@field detail table
---@field label? string                    -- what the list shows; renderers set it
---@field decorations? lese.Decoration[]

---What a previewer shows.
---@class lese.PreviewItem
---@field content string[]
---@field line? integer       -- 1-based line to put the cursor on
---@field column? integer     -- 1-based byte column
---@field filetype? string
---@field filename? string

---@class lese.CollectParams
---@field args string[]

---@class lese.CurateParams
---@field args string[]
---@field query string

---@class lese.MatchParams
---@field query string
---@field items lese.Item[]   -- do not modify; emit copies when changing an item

---@class lese.SortParams
---@field items lese.Item[]   -- sort in place

---@class lese.RenderParams
---@field items lese.Item[]   -- the visible items; set `label` and `decorations` in place

---@class lese.PreviewParams
---@field item lese.Item

---@class lese.InvokeParams
---@field item? lese.Item                -- the item under the cursor
---@field selected_items? lese.Item[]    -- the selected items, when any is selected
---@field filtered_items lese.Item[]     -- every item the matcher let through
---@field query string

---Collects items once per picker: `ctx:emit()` them.
---@class lese.Source
---@field name string
---@field collect fun(ctx: lese.Context, params: lese.CollectParams)

---Collects items for each query, for sources that search themselves (grep).
---@class lese.Curator
---@field name string
---@field curate fun(ctx: lese.Context, params: lese.CurateParams)

---Emits the items that match the query, with decorations on the matched part.
---@class lese.Matcher
---@field name string
---@field match fun(ctx: lese.Context, params: lese.MatchParams)
---@field incremental? boolean  -- show results while matching (curators)

---@class lese.Sorter
---@field name string
---@field sort fun(ctx: lese.Context, params: lese.SortParams)

---@class lese.Renderer
---@field name string
---@field render fun(ctx: lese.Context, params: lese.RenderParams)

---@class lese.Previewer
---@field name string
---@field preview fun(ctx: lese.Context, params: lese.PreviewParams): lese.PreviewItem?

---Does something with the chosen items. Return true to keep the picker open.
---@class lese.Action
---@field name string
---@field invoke fun(ctx: lese.Context, params: lese.InvokeParams): boolean?

---Transforms an item on its way in, or drops it by returning nil.
---@class lese.Refiner
---@field name string
---@field refine fun(ctx: lese.Context, item: lese.Item): lese.Item?

---@class lese.Size
---@field width integer
---@field height integer

---@class lese.Style
---@field input lese.Border
---@field list lese.Border
---@field preview? lese.Border

---@class lese.Layout
---@field input lese.Dimension
---@field list lese.Dimension
---@field preview? lese.Dimension

---Lays the picker's windows out on the screen.
---@class lese.Coordinator
---@field name string
---@field style fun(theme: lese.Theme): lese.Style
---@field layout fun(screen: lese.Size): lese.Layout

---@alias lese.Divider string[] -- left, horizontal, right, top, vertical, bottom

---@class lese.Theme
---@field border lese.Border
---@field divider lese.Divider
---@field spinner? string[]
---@field head_symbol? string
---@field fail_symbol? string
---@field matcher_icon? string
---@field sorter_icon? string
---@field renderer_icon? string
---@field previewer_icon? string

---@class lese.Setting
---@field coordinator lese.Coordinator
---@field theme lese.Theme

---@class lese.ActionPickerParams
---@field matchers lese.Matcher[]
---@field coordinator lese.Coordinator

---@class lese.PickerParams
---@field actions table<string, lese.Action>
---@field default_action string
---@field matchers? lese.Matcher[]      -- required for a source picker
---@field sorters? lese.Sorter[]
---@field renderers? lese.Renderer[]
---@field previewers? lese.Previewer[]
---@field coordinator? lese.Coordinator
---@field theme? lese.Theme

---What custom.lua's function receives.
---@class lese.Entrypoint
---@field define_picker_from_source fun(name: string, source: lese.Source, params: lese.PickerParams)
---@field define_picker_from_curator fun(name: string, curator: lese.Curator, params: lese.PickerParams)
---@field refine_setting fun(setting: lese.Setting|{})
---@field refine_action_picker fun(params: lese.ActionPickerParams|{})
