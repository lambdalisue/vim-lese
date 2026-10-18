-- Where lese's types live, for lua-language-server. custom.lua is annotated
-- with them (lese.Entrypoint and the rest); hand these directories to the
-- server's `workspace.library` in whatever client runs it.

local host = require("lese.host")

local M = {}

---The lua/ directories of lese and of every lese-* extension on
---'runtimepath', in 'runtimepath' order, after the directories in `base` (a
---library already configured). A new list is returned and directories are
---listed once, so calling it again on its own result adds nothing.
---@param base? string[]
---@return string[]
function M.library(base)
  local dirs, seen = {}, {}
  local function add(dir)
    if not seen[dir] then
      seen[dir] = true
      dirs[#dirs + 1] = dir
    end
  end
  for _, dir in ipairs(base or {}) do
    add(dir)
  end
  local rtp = host.eval("&runtimepath")
  for _, pattern in ipairs({ "lua/lese", "lua/lese-*" }) do
    for _, path in ipairs(host.fn.globpath(rtp, pattern, false, true)) do
      add(host.fn.fnamemodify(path, ":h"))
    end
  end
  return dirs
end

return M
