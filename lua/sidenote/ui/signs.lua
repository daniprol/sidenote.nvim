-- lua/sidenote/ui/signs.lua

local M = {}

local sign_group = 'sidenote_signs'

function M.setup()
  -- Define the sign
  local config = require('sidenote').config
  local emoji = config.ui.signs.emoji or '📝'

  -- Use pcall to catch any errors in sign definition
  local success, err = pcall(function()
    vim.fn.sign_define(sign_group, {
      text = emoji,
      texthl = 'SidenoteSign',
      numhl = '',
      linehl = ''
    })
  end)

  if not success then
    vim.notify("Sidenote: Failed to define sign: " .. err, vim.log.levels.ERROR)
    return
  end

  -- Setup highlight group
  vim.api.nvim_set_hl(0, 'SidenoteSign', {
    fg = vim.api.nvim_get_hl_by_name('Comment', true).foreground,
  })

  -- Debug: verify sign was defined
  local defined = vim.fn.sign_getdefined(sign_group)
  if #defined == 0 then
    vim.notify("Sidenote: Sign definition failed", vim.log.levels.ERROR)
  end
end

function M.update_display(bufnr, notes)
  -- Ensure sign is defined before using it
  local defined_signs = vim.fn.sign_getdefined(sign_group)
  if #defined_signs == 0 then
    M.setup()
  end

  M.clear_display(bufnr)

  if not notes or #notes == 0 then
    return
  end

  local config = require('sidenote').config

  for _, note in ipairs(notes) do
    -- Double-check sign exists before placing
    if #vim.fn.sign_getdefined(sign_group) > 0 then
      vim.fn.sign_place(0, sign_group, sign_group, bufnr, {
        lnum = note.current_line,
        priority = config.ui.signs.priority or 10
      })
    else
      vim.notify("Sidenote: Failed to define sign", vim.log.levels.ERROR)
    end
  end
end

function M.clear_display(bufnr)
  vim.fn.sign_unplace(sign_group, { buffer = bufnr })
end

function M.cleanup()
  vim.fn.sign_undefine(sign_group)
end

return M