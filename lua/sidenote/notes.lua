-- lua/sidenote/notes.lua

local sidenote = require('sidenote')
local paths = require('sidenote.paths')
local ui = require('sidenote.ui')
local persistence = require('sidenote.persistence')

local M = {}

---@private
-- Gets the visual selection range and text.
---@return integer, integer, integer, integer, string[]|nil
local function get_visual_selection()
  local _, start_row, start_col, _ = unpack(vim.fn.getpos("'<"))
  local _, end_row, end_col, _ = unpack(vim.fn.getpos("'>"))
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

  if #lines == 1 then
    local line = lines[1]
    local selected_text = line:sub(start_col, end_col)
    return start_row, start_col, end_row, end_col, { selected_text }
  else
    local result = {}
    for i, line in ipairs(lines) do
      if i == 1 then
        result[i] = line:sub(start_col)
      elseif i == #lines then
        result[i] = line:sub(1, end_col)
      else
        result[i] = line
      end
    end
    return start_row, start_col, end_row, end_col, result
  end
end

---@private
-- Finds the current position of a note's anchor text in the buffer.
-- Returns coordinates in the format required by nvim_buf_set_extmark.
---@param bufnr integer The buffer to search in.
---@param note table The note object with its anchor text.
---@return table|nil A table with {line, start_col, end_line, end_col} (0-indexed) or nil.
local function find_anchor_position(bufnr, note)
  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local anchor_lines = note.anchor
  if not anchor_lines or #anchor_lines == 0 then
    return nil
  end

  for line_idx = 0, #buf_lines - #anchor_lines do
    local is_block_match = true
    for anchor_idx = 1, #anchor_lines do
      if buf_lines[line_idx + anchor_idx] ~= anchor_lines[anchor_idx] then
        is_block_match = false
        break
      end
    end

    if is_block_match then
      local start_line = line_idx
      local end_line = line_idx + #anchor_lines - 1
      local start_col = (note.original_start_col or 1) - 1
      local end_col

      if #anchor_lines == 1 then
        -- For single-line notes, end_col is relative to its start
        end_col = start_col + #anchor_lines[1]
      else
        -- For multi-line notes, end_col is the byte length of the last line of the anchor
        end_col = #anchor_lines[#anchor_lines]
      end

      return { line = start_line, start_col = start_col, end_line = end_line, end_col = end_col }
    end
  end

  return nil
end

---@public
-- Prompts user for a note and saves it for the current visual selection.
function M.create_note()
  if not sidenote.config.enabled then return end
  local start_line, start_col, end_line, end_col, anchor_text = get_visual_selection()
  if not anchor_text or #anchor_text == 0 then
    vim.notify('Sidenote: No visual selection found.', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local existing_notes = M.find_all_notes_in_buffer(bufnr)
  for _, note in ipairs(existing_notes) do
    local existing_start = note.pos.line + 1
    local existing_end = note.pos.end_line + 1
    if start_line <= existing_end and existing_start <= end_line then
      vim.notify('Sidenote: Cannot create a note that overlaps with an existing one.', vim.log.levels.ERROR)
      return
    end
  end

  vim.ui.input({ prompt = 'Sidenote: ' }, function(note_text)
    if not note_text or note_text == '' then
      vim.notify('Sidenote: Note creation cancelled.', vim.log.levels.INFO)
      return
    end

    if string.len(note_text) > sidenote.config.max_char_count then
      vim.notify(string.format('Sidenote: Note exceeds max length of %d', sidenote.config.max_char_count), vim.log.levels.WARN)
      return
    end

    local note_filepath = paths.get_note_filepath(bufnr)
    if not note_filepath then
      vim.notify('Sidenote: Could not determine note file path.', vim.log.levels.ERROR)
      return
    end

    local new_note = {
      id = os.date('!%Y-%m-%dT%H:%M:%SZ') .. '-' .. tostring(math.random()),
      original_start_line = start_line,
      original_start_col = start_col,
      original_end_line = end_line,
      original_end_col = end_col,
      text = note_text,
      anchor = anchor_text,
    }

    local all_notes = M.parse_notes_for_buffer(bufnr) or {}
    table.insert(all_notes, new_note)

    persistence.save(all_notes, note_filepath)
    vim.notify('Sidenote: Note saved successfully!')

    local located_notes = M.find_all_notes_in_buffer(bufnr)
    ui.update_display(bufnr, located_notes)
  end)
end

---@public
-- Finds all notes and their current positions in the buffer.
---@param bufnr integer The buffer number.
---@return table A list of note objects, each with a 'pos' table.
function M.find_all_notes_in_buffer(bufnr)
  local located_notes = {}
  local all_notes = M.parse_notes_for_buffer(bufnr)
  if not all_notes then
    return located_notes
  end

  for _, note in ipairs(all_notes) do
    local pos = find_anchor_position(bufnr, note)
    if pos then
      note.pos = pos
      table.insert(located_notes, note)
    end
  end

  return located_notes
end

---@public
-- Deletes the note found at the current cursor position.
function M.delete_note_at_cursor()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local located_notes = M.find_all_notes_in_buffer(bufnr)
  if #located_notes == 0 then
    return
  end

  local note_to_delete_id = nil
  for _, note in ipairs(located_notes) do
    local note_start_line = note.pos.line + 1
    local note_end_line = note.pos.end_line + 1
    if cursor_line >= note_start_line and cursor_line <= note_end_line then
      note_to_delete_id = note.id
      break
    end
  end

  if not note_to_delete_id then
    vim.notify('Sidenote: No note found at cursor position.', vim.log.levels.INFO)
    return
  end

  local all_notes_raw = M.parse_notes_for_buffer(bufnr)
  local updated_notes = {}
  for _, note in ipairs(all_notes_raw) do
    if note.id ~= note_to_delete_id then
      table.insert(updated_notes, note)
    end
  end

  local note_filepath = paths.get_note_filepath(bufnr)
  persistence.save(updated_notes, note_filepath)

  vim.notify('Sidenote: Note deleted successfully.')

  local new_located_notes = M.find_all_notes_in_buffer(bufnr)
  ui.update_display(bufnr, new_located_notes)
end

---@public
-- Finds and prompts to update a note at the current cursor position.
function M.edit_note_at_cursor()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local located_notes = M.find_all_notes_in_buffer(bufnr)
  if #located_notes == 0 then
    return
  end

  local note_to_edit = nil
  for _, note in ipairs(located_notes) do
    local note_start_line = note.pos.line + 1
    local note_end_line = note.pos.end_line + 1
    if cursor_line >= note_start_line and cursor_line <= note_end_line then
      note_to_edit = note
      break
    end
  end

  if not note_to_edit then
    vim.notify('Sidenote: No note found at cursor position.', vim.log.levels.INFO)
    return
  end

  vim.ui.input({ prompt = 'Edit note: ', default = note_to_edit.text }, function(new_text)
    if not new_text or new_text == '' then
      vim.notify('Sidenote: Edit cancelled.', vim.log.levels.INFO)
      return
    end

    if string.len(new_text) > sidenote.config.max_char_count then
      vim.notify(string.format('Sidenote: Note exceeds max length of %d', sidenote.config.max_char_count), vim.log.levels.WARN)
      return
    end

    local all_notes_raw = M.parse_notes_for_buffer(bufnr)
    for i, note in ipairs(all_notes_raw) do
      if note.id == note_to_edit.id then
        all_notes_raw[i].text = new_text
        break
      end
    end

    local note_filepath = paths.get_note_filepath(bufnr)
    persistence.save(all_notes_raw, note_filepath)

    vim.notify('Sidenote: Note updated successfully.')

    local located_notes = M.find_all_notes_in_buffer(bufnr)
    ui.update_display(bufnr, located_notes)
  end)
end

---@public
-- Deletes all notes for the current buffer.
function M.delete_all_notes_for_buffer()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local note_filepath = paths.get_note_filepath(bufnr)

  if note_filepath and vim.fn.filereadable(note_filepath) == 1 then
    os.remove(note_filepath)
    vim.notify('Sidenote: All notes for this buffer have been deleted.')
    ui.clear_display(bufnr)
  else
    vim.notify('Sidenote: No notes found for this buffer.', vim.log.levels.INFO)
  end
end

---@public
-- Parses the note file for a given buffer.
---@param bufnr integer The buffer number.
---@return table|nil The parsed notes table or nil.
function M.parse_notes_for_buffer(bufnr)
  local note_filepath = paths.get_note_filepath(bufnr)
  return M.parse_notes_from_file(note_filepath)
end

---@public
-- Parses a note file from a given filepath.
---@param filepath string The path to the note file.
---@return table|nil The parsed notes table or nil.
function M.parse_notes_from_file(filepath)
  return persistence.load(filepath)
end

return M
