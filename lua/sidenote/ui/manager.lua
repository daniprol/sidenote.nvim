-- lua/sidenote/ui/manager.lua

local M = {}

function M.new(display_provider)
  local manager = {
    provider = display_provider
  }

  function manager:update(bufnr, notes)
    if self.provider and self.provider.update_display then
      self.provider.update_display(bufnr, notes)
    end
  end

  function manager:clear(bufnr)
    if self.provider and self.provider.clear_display then
      self.provider.clear_display(bufnr)
    end
  end

  function manager:setup()
    if self.provider and self.provider.setup then
      self.provider.setup()
    end
  end

  function manager:cleanup()
    if self.provider and self.provider.cleanup then
      self.provider.cleanup()
    end
  end

  return manager
end

return M