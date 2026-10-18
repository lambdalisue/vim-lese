local define = require("lese.define")

---Show a help tag of another language as "tag@lang", with "@lang" dimmed.
---Reads `item.detail.lang`.
---@return lese.Renderer
return function()
  return define.renderer({
    name = "builtin.renderer.helptag",
    render = function(ctx, params)
      for i, item in ipairs(params.items) do
        if i % 256 == 0 then
          ctx:checkpoint()
        end
        local lang = item.detail.lang
        if type(lang) == "string" and lang ~= "" then
          item.label = item.value .. "@" .. lang
          local decorations = {}
          for j, d in ipairs(item.decorations or {}) do
            decorations[j] = d
          end
          decorations[#decorations + 1] =
            { column = #item.value + 1, length = #lang + 1, highlight = "Comment" }
          item.decorations = decorations
        end
      end
    end,
  })
end
