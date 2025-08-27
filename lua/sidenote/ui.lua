-- lua/sidenote/ui.lua

local M = {}

local virtual_text_namespace = nil
local anchor_namespace = nil
local sign_group = 'sidenote_signs'

function M.setup()
  local config = require('sidenote').config

  virtual_text_namespace = vim.api.nvim_create_namespace('sidenote_virtual_text')
  anchor_namespace = vim.api.nvim_create_namespace('sidenote_anchors')

  vim.api.nvim_set_hl(0, 'SidenoteVirtualText',
    { fg = vim.api.nvim_get_hl_by_name('Comment', true).foreground, italic = true })

  if config.anchor_highlight.enabled then
    vim.api.nvim_set_hl(0, config.anchor_highlight.default_hl, { link = 'ColorColumn', default = true })
    vim.api.nvim_set_hl(0, config.anchor_highlight.active_hl, { link = 'Visual', default = true })
  end

  if config.signs_enabled then
    vim.fn.sign_define(sign_group, { text = config.sign_emoji, texthl = 'Comment' })
  end
end

function M.update_display(bufnr, notes)
  M.clear_display(bufnr)

  if not notes or #notes == 0 then
    return
  end

  local config = require('sidenote').config

  for _, note in ipairs(notes) do
    local pos = note.pos

    local display_text = note.text
    if #display_text > config.virtual_text.max_length then
      display_text = display_text:sub(1, config.virtual_text.max_length - 3) .. '...'
    end
    local virt_text = { { config.virtual_text.prefix .. ' ' .. display_text, 'SidenoteVirtualText' } }

    vim.api.nvim_buf_set_extmark(bufnr, virtual_text_namespace, pos.line, pos.start_col, {
      virt_text = virt_text,
      virt_text_pos = config.virtual_text.position,
    })

    if config.signs_enabled then
      vim.fn.sign_place(0, sign_group, sign_group, bufnr, { lnum = pos.line + 1, priority = 10 })
    end
  end

  M.update_anchor_highlights(bufnr, notes)
end

function M.update_anchor_highlights(bufnr, notes)
  local config = require('sidenote').config

  if not config.anchor_highlight.enabled then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, anchor_namespace, 0, -1)

  if not notes or #notes == 0 then
    return
  end

  for _, note in ipairs(notes) do
    local pos = note.pos
    vim.api.nvim_buf_set_extmark(bufnr, anchor_namespace, pos.line, pos.start_col, {
      end_line = pos.line + #note.anchor - 1,
      end_col = pos.end_col,
      hl_group = config.anchor_highlight.default_hl,
      priority = config.anchor_highlight.priority,
    })
  end
end

function M.update_anchor_highlight_styles(bufnr, cursor_line, cursor_col)
  local config = require('sidenote').config
  if not config.anchor_highlight.enabled then
    return
  end

  local notes = require('sidenote.notes').find_all_notes_in_buffer(bufnr)
  M.update_anchor_highlights(bufnr, notes) -- Redraw default highlights first

  for _, note in ipairs(notes) do
    local pos = note.pos
    local end_line = pos.line + #note.anchor - 1

    if cursor_line - 1 >= pos.line and cursor_line - 1 <= end_line then
      -- A simple line check is sufficient for the hover effect
      vim.api.nvim_buf_set_extmark(bufnr, anchor_namespace, pos.line, pos.start_col, {
        end_line = end_line,
        end_col = pos.end_col,
        hl_group = config.anchor_highlight.active_hl,
        priority = config.anchor_highlight.priority + 1, -- Higher priority for hover
      })
      break                                              -- Highlight only the first note found at the cursor
    end
  end
end

function M.clear_display(bufnr)
  if virtual_text_namespace then
    vim.api.nvim_buf_clear_namespace(bufnr, virtual_text_namespace, 0, -1)
  end

  if anchor_namespace then
    vim.api.nvim_buf_clear_namespace(bufnr, anchor_namespace, 0, -1)
  end

  if require('sidenote').config.signs_enabled then
    vim.fn.sign_unplace(sign_group, { buffer = bufnr })
  end
end

return M
