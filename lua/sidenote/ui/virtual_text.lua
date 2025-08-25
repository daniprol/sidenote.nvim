-- lua/sidenote/ui/virtual_text.lua

local M = {}

local namespace

function M.setup()
  -- Create namespace and setup highlight groups
  namespace = vim.api.nvim_create_namespace('sidenote_virtual_text')

  vim.api.nvim_set_hl(0, 'SidenoteVirtualText', {
    fg = vim.api.nvim_get_hl_by_name('Comment', true).foreground,
    italic = true,
    bold = false
  })
end

function M.update_display(bufnr, notes)
  -- Ensure namespace is initialized
  if not namespace then
    M.setup()
  end

  M.clear_display(bufnr)

  if not notes or #notes == 0 then
    return
  end

  for _, note in ipairs(notes) do
    local line = note.current_line - 1 -- Convert to 0-indexed
    local start_col = note.start_col or 0
    local end_col = note.end_col or #vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]

    -- Create virtual text with note content
    local config = require('sidenote').config
    local prefix = config.ui.virtual_text.prefix or '📝'
    local max_length = config.ui.virtual_text.max_length or 50

    -- Truncate note text if too long
    local display_text = note.text
    if #display_text > max_length then
      display_text = display_text:sub(1, max_length - 3) .. '...'
    end

    local virt_text = {{prefix .. ' ' .. display_text, 'SidenoteVirtualText'}}

    vim.api.nvim_buf_set_extmark(bufnr, namespace, line, start_col, {
      virt_text = virt_text,
      virt_text_pos = config.ui.virtual_text.position or 'eol',
      end_col = end_col,
      hl_group = 'SidenoteHighlight',
      priority = 100
    })
  end
end

function M.clear_display(bufnr)
  if namespace then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
end

function M.cleanup()
  -- Cleanup if needed
end

return M