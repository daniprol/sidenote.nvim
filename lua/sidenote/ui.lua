-- lua/sidenote/ui.lua

local M = {}

local virtual_text_namespace = nil
local anchor_namespace = nil
local sign_group = 'sidenote_signs'

-- Initialize virtual text namespace and signs
function M.setup()
  local config = require('sidenote').config

  -- Setup virtual text namespace
  virtual_text_namespace = vim.api.nvim_create_namespace('sidenote_virtual_text')

  -- Setup anchor namespace
  anchor_namespace = vim.api.nvim_create_namespace('sidenote_anchors')

  -- Setup highlight groups
  vim.api.nvim_set_hl(0, 'SidenoteVirtualText', {
    fg = vim.api.nvim_get_hl_by_name('Comment', true).foreground,
    italic = true,
    bold = false
  })

  -- Setup anchor highlight groups if enabled
  if config.anchor_highlight.enabled then
    -- Default anchor highlight (subtle)
    vim.api.nvim_set_hl(0, config.anchor_highlight.default_hl, {
      bg = vim.api.nvim_get_hl_by_name('Visual', true).background,
      blend = 80,  -- Very subtle
    })

    -- Active anchor highlight (more visible)
    vim.api.nvim_set_hl(0, config.anchor_highlight.active_hl, {
      bg = vim.api.nvim_get_hl_by_name('Visual', true).background,
      blend = 60,  -- More visible
      underline = true,
    })
  end

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
    local start_col = note.current_start_col or 0
    local end_col = note.current_end_col or #vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]

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

  -- Update anchor highlights
  M.update_anchor_highlights(bufnr, notes)
end

-- Update anchor highlights for notes
function M.update_anchor_highlights(bufnr, notes)
  local config = require('sidenote').config

  if not config.anchor_highlight.enabled or not anchor_namespace then
    return
  end

  -- Clear existing anchor highlights
  vim.api.nvim_buf_clear_namespace(bufnr, anchor_namespace, 0, -1)

  if not notes or #notes == 0 then
    return
  end

  for _, note in ipairs(notes) do
    local line = note.current_line - 1
    local start_col = note.current_start_col or 0
    local end_col = note.current_end_col or #vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]

    -- Only create highlight if we have a valid range
    if start_col < end_col then
      vim.api.nvim_buf_set_extmark(bufnr, anchor_namespace, line, start_col, {
        end_col = end_col,
        hl_group = config.anchor_highlight.default_hl,
        priority = config.anchor_highlight.priority,
        -- Store note id for cursor tracking
        virt_text = {{"", ""}}, -- Empty virtual text to maintain extmark
        virt_text_pos = 'overlay',
      })
    end
  end
end

-- Check if cursor is within any anchor range and update highlights
function M.update_anchor_highlight_styles(bufnr, cursor_line, cursor_col)
  local config = require('sidenote').config

  if not config.anchor_highlight.enabled or not anchor_namespace then
    return
  end

  local notes = require('sidenote.notes').find_all_notes_in_buffer(bufnr)
  if not notes or #notes == 0 then
    return
  end

  -- Clear existing anchor highlights before updating
  vim.api.nvim_buf_clear_namespace(bufnr, anchor_namespace, 0, -1)

  -- Debug: Print cursor position and notes
  if config.debug then
    print(string.format("DEBUG: Cursor at line %d, col %d (1-indexed)", cursor_line, cursor_col))
    for i, note in ipairs(notes) do
      print(string.format("DEBUG: Note %d: line %d, start_col %s, end_col %s, text: %s",
        i, note.current_line, tostring(note.current_start_col), tostring(note.current_end_col), note.text))
    end
  end

  -- Find which note (if any) contains the cursor
  -- Note: cursor_col is 1-indexed, extmark positions are 0-indexed
  local active_note_id = nil
  for _, note in ipairs(notes) do
    local note_line = note.current_line
    local start_col = note.current_start_col or 0
    local end_col = note.current_end_col or #vim.api.nvim_buf_get_lines(bufnr, note_line - 1, note_line, false)[1]

    -- Convert cursor column to 0-indexed for comparison
    local cursor_col_0 = cursor_col - 1

    if cursor_line == note_line and cursor_col_0 >= start_col and cursor_col_0 < end_col then
      active_note_id = note.id
      if config.debug then
        print(string.format("DEBUG: Cursor in note range: line %d, cursor_col_0 %d, range [%d, %d)",
          cursor_line, cursor_col_0, start_col, end_col))
      end
      break
    end
  end

  -- Update all anchor highlights based on cursor position
  for _, note in ipairs(notes) do
    local line = note.current_line - 1
    local start_col = note.current_start_col or 0
    local end_col = note.current_end_col or #vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]

    if start_col < end_col then
      local hl_group = (active_note_id == note.id)
        and config.anchor_highlight.active_hl
        or config.anchor_highlight.default_hl

      vim.api.nvim_buf_set_extmark(bufnr, anchor_namespace, line, start_col, {
        end_col = end_col,
        hl_group = hl_group,
        priority = config.anchor_highlight.priority,
        virt_text = {{"", ""}},
        virt_text_pos = 'overlay',
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

  -- Clear anchor highlights
  if anchor_namespace then
    vim.api.nvim_buf_clear_namespace(bufnr, anchor_namespace, 0, -1)
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

  if anchor_namespace then
    -- Clear all anchor highlights across all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, anchor_namespace, 0, -1)
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