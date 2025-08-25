-- lua/sidenote/ui/init.lua

local M = {}

-- Interface for UI display implementations
M.DisplayProvider = {
  update_display = function(bufnr, notes) end,
  clear_display = function(bufnr) end,
  setup = function() end,
  cleanup = function() end
}

return M