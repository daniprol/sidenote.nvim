-- lua/sidenote/ui.lua

local M = {}

local virtual_text_namespace = nil
local sign_group = 'sidenote_signs'

-- Initialize virtual text namespace and signs
function M.setup()
  local config = require('sidenote').config

  -- Setup virtual text namespace
  virtual_text_namespace = vim.api.nvim_create_namespace('sidenote_virtual_text')

  -- Setup highlight groups
  vim.api.nvim_set_hl(0, 'SidenoteVirtualText', {
    fg = vim.api.nvim_get_hl_by_name('Comment', true).foreground,
    italic = true,
    bold = false
  })

  -- Setup signs if enabled
  if config.signs_enabled then
    vim.fn.sign_define(sign_group, {
      text = config.sign_emoji,
      texthl = 'SidenoteSign',
      numhl = '',
      linehl = ''
    })

    vim.api.nvim_set_hl(0, 'SidenoteSign', {
      fg = vim.api.nvim_get_hl_by_name('Comment', true).foreground,
    })
  end
end

-- Update display for notes
function M.update_display(bufnr, notes)
  M.clear_display(bufnr)

  if not notes or #notes == 0 then
    return
  end

  local config = require('sidenote').config

  for _, note in ipairs(notes) do
    local line = note.current_line - 1 -- Convert to 0-indexed
    local start_col = note.start_col or 0
    local end_col = note.end_col or #vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]

    -- Add virtual text
    local prefix = config.virtual_text.prefix or '📝'
    local max_length = config.virtual_text.max_length or 50

    -- Truncate note text if too long
    local display_text = note.text
    if #display_text > max_length then
      display_text = display_text:sub(1, max_length - 3) .. '...'
    end

    local virt_text = {{prefix .. ' ' .. display_text, 'SidenoteVirtualText'}}

    vim.api.nvim_buf_set_extmark(bufnr, virtual_text_namespace, line, start_col, {
      virt_text = virt_text,
      virt_text_pos = config.virtual_text.position or 'eol',
      end_col = end_col,
      hl_group = 'SidenoteHighlight',
      priority = 100
    })

    -- Add sign if enabled
    if config.signs_enabled then
      vim.fn.sign_place(0, sign_group, sign_group, bufnr, {
        lnum = note.current_line,
        priority = 10
      })
    end
  end
end

-- Clear display for buffer
function M.clear_display(bufnr)
  -- Clear virtual text
  if virtual_text_namespace then
    vim.api.nvim_buf_clear_namespace(bufnr, virtual_text_namespace, 0, -1)
  end

  -- Clear signs if enabled
  local config = require('sidenote').config
  if config.signs_enabled then
    vim.fn.sign_unplace(sign_group, { buffer = bufnr })
  end
end

-- Cleanup function
function M.cleanup()
  if virtual_text_namespace then
    -- Clear all virtual text across all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, virtual_text_namespace, 0, -1)
      end
    end
  end

  -- Clean up signs
  local config = require('sidenote').config
  if config.signs_enabled then
    vim.fn.sign_unplace(sign_group)
    vim.fn.sign_undefine(sign_group)
  end
end

return M