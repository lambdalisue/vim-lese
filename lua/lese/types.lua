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
---@field id any                           -- unique within a source; selection is kept by id
---@field value string                     -- what matchers match against
---@field detail table                     -- whatever later modules need (a path, a buffer number, …)
---@field label? string                    -- what the list shows; renderers set it, and `value` is shown without one
---@field decorations? lese.Decoration[]   -- highlighted ranges of the label; matchers and renderers add them

---What a previewer shows.
---@class lese.PreviewItem
---@field content string[]    -- the lines to show
---@field line? integer       -- 1-based line to put the cursor on
---@field column? integer     -- 1-based byte column
---@field filetype? string    -- the preview buffer's filetype, for syntax highlighting
---@field filename? string    -- names the preview buffer and the LesePreviewRendered event

---What a source's `collect` receives.
---@class lese.CollectParams
---@field args string[]       -- the picker's arguments, from `:Lese {picker} {args}...`

---What a curator's `curate` receives.
---@class lese.CurateParams
---@field args string[]       -- the picker's arguments, from `:Lese {picker} {args}...`
---@field query string        -- the query typed so far

---What a matcher's `match` receives.
---@class lese.MatchParams
---@field query string        -- the query typed so far
---@field items lese.Item[]   -- do not modify; emit copies when changing an item

---What a sorter's `sort` receives.
---@class lese.SortParams
---@field items lese.Item[]   -- sort in place

---What a renderer's `render` receives.
---@class lese.RenderParams
---@field items lese.Item[]   -- the visible items; set `label` and `decorations` in place

---What a previewer's `preview` receives.
---@class lese.PreviewParams
---@field item lese.Item      -- the item under the cursor

---What an action's `invoke` receives.
---@class lese.InvokeParams
---@field item? lese.Item                -- the item under the cursor
---@field selected_items? lese.Item[]    -- the selected items, when any is selected
---@field filtered_items lese.Item[]     -- every item the matcher let through
---@field query string                   -- the query when the action was invoked

---Collects items once per picker: `ctx:emit()` them.
---@class lese.Source
---@field name string         -- shown in errors, warnings and the help
---Collects the items and hands them over with `ctx:emit()`; calls `ctx:checkpoint()` in long loops.
---@field collect fun(ctx: lese.Context, params: lese.CollectParams)

---Collects items for each query, for sources that search themselves (grep).
---@class lese.Curator
---@field name string         -- shown in errors, warnings and the help
---Searches for the query and hands the hits over with `ctx:emit()`; runs again on every query change.
---@field curate fun(ctx: lese.Context, params: lese.CurateParams)

---Emits the items that match the query, with decorations on the matched part.
---@class lese.Matcher
---@field name string         -- shown in errors, warnings and the help
---Emits the items of `params.items` that match `params.query`, as copies when it adds decorations.
---@field match fun(ctx: lese.Context, params: lese.MatchParams)
---@field incremental? boolean  -- show results while matching (curators)
---True when every item `query` lets through is one `previous` let through, so the picker may match
---only the last results; leave it out when unsure.
---@field narrows? fun(previous: string, query: string): boolean

---Reorders the filtered items.
---@class lese.Sorter
---@field name string         -- shown in errors, warnings and the help
---Reorders `params.items` in place, keeping every item.
---@field sort fun(ctx: lese.Context, params: lese.SortParams)

---Sets how the visible items look.
---@class lese.Renderer
---@field name string         -- shown in errors, warnings and the help
---Sets `label` and `decorations` of `params.items` in place, keeping every item.
---@field render fun(ctx: lese.Context, params: lese.RenderParams)

---Shows the item under the cursor in the preview window.
---@class lese.Previewer
---@field name string         -- shown in errors, warnings and the help
---Returns what to show for `params.item`, or nil to show nothing.
---@field preview fun(ctx: lese.Context, params: lese.PreviewParams): lese.PreviewItem?

---Does something with the chosen items. Return true to keep the picker open.
---@class lese.Action
---@field name string         -- shown in errors, warnings and the help
---Acts on the item under the cursor or the selected items; returns true to keep the picker open.
---@field invoke fun(ctx: lese.Context, params: lese.InvokeParams): boolean?

---Transforms an item on its way in, or drops it by returning nil.
---@class lese.Refiner
---@field name string         -- shown in errors, warnings and the help
---Returns the item, changed or not, or nil to drop it.
---@field refine fun(ctx: lese.Context, item: lese.Item): lese.Item?

---The size of the editor screen, in cells.
---@class lese.Size
---@field width integer       -- columns
---@field height integer      -- lines

---The borders of each picker window.
---@class lese.Style
---@field input lese.Border           -- border of the query line
---@field list lese.Border            -- border of the item list
---@field preview? lese.Border        -- border of the preview; nil when there is no preview window

---Where each picker window goes on the screen.
---@class lese.Layout
---@field input lese.Dimension        -- position and size of the query line
---@field list lese.Dimension         -- position and size of the item list
---@field preview? lese.Dimension     -- position and size of the preview; nil hides it

---Lays the picker's windows out on the screen.
---@class lese.Coordinator
---@field name string                 -- shown in errors and warnings
---Picks each window's border from the theme.
---@field style fun(theme: lese.Theme): lese.Style
---Places each window on a screen of the given size; called again when the editor is resized.
---@field layout fun(screen: lese.Size): lese.Layout

---@alias lese.Divider string[] -- left, horizontal, right, top, vertical, bottom

---The borders, dividers, symbols and icons of the picker. Unset optional
---fields fall back to lese's defaults.
---@class lese.Theme
---@field border lese.Border          -- the frame around the picker windows
---@field divider lese.Divider        -- the lines between windows that share a frame
---@field spinner? string[]           -- frames shown in turn while collecting or matching
---@field head_symbol? string         -- the prompt in front of the query
---@field fail_symbol? string         -- shown in place of the prompt or spinner when a module failed
---@field matcher_icon? string        -- prefixes the matcher number in the indicator when a picker has several
---@field sorter_icon? string         -- prefixes the sorter number in the indicator when a picker has several
---@field renderer_icon? string       -- prefixes the renderer number in the indicator when a picker has several
---@field previewer_icon? string      -- prefixes the previewer number in the indicator when a picker has several

---What every picker uses unless it says otherwise; see `x.refine_setting`.
---@class lese.Setting
---@field coordinator lese.Coordinator  -- default: `builtin.coordinator.modern()`
---@field theme lese.Theme              -- default: `builtin.theme.MODERN`

---How the action selector looks; see `x.refine_action_picker`.
---@class lese.ActionPickerParams
---@field matchers lese.Matcher[]       -- filter the action names; default: `builtin.matcher.fzf()`
---@field coordinator lese.Coordinator  -- default: a small `modern` coordinator without preview

---The parameters of `x.define_picker_from_source` and `x.define_picker_from_curator`.
---@class lese.PickerParams
---@field actions table<string, lese.Action>  -- action name to action; names must not start with `@`
---@field default_action string               -- the key of `actions` invoked on <CR>
---@field matchers? lese.Matcher[]      -- required for a source picker; <Plug>(lese-switch-matcher-*) cycles them
---@field sorters? lese.Sorter[]        -- <Plug>(lese-switch-sorter-*) cycles them; the first is used initially
---@field renderers? lese.Renderer[]    -- <Plug>(lese-switch-renderer-*) cycles them; the first is used initially
---@field previewers? lese.Previewer[]  -- <Plug>(lese-switch-previewer-*) cycles them; none means no preview
---@field coordinator? lese.Coordinator -- default: the one set by `x.refine_setting`
---@field theme? lese.Theme             -- default: the one set by `x.refine_setting`

---What custom.lua's function receives.
---@class lese.Entrypoint
---Declare a picker `name` over a source, opened with `:Lese {name}`; `params.matchers` is required.
---@field define_picker_from_source fun(name: string, source: lese.Source, params: lese.PickerParams)
---
---Declare a picker `name` whose curator searches again for each query, opened with `:Lese {name}`.
---@field define_picker_from_curator fun(name: string, curator: lese.Curator, params: lese.PickerParams)
---
---Set the coordinator and theme every picker uses unless it says otherwise.
---@field refine_setting fun(setting: lese.Setting|{})
---
---Set the matchers and coordinator of the action selector.
---@field refine_action_picker fun(params: lese.ActionPickerParams|{})
