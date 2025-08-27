-- lua/sidenote/notes.lua

local sidenote = require('sidenote')
local paths = require('sidenote.paths')
local ui = require('sidenote.ui')
local persistence = require('sidenote.persistence')

local M = {}

-- (Helper functions like get_visual_selection and find_anchor_position remain the same)

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
---@param bufnr integer The buffer to search in.
---@param note table The note object with its anchor text.
---@return table|nil A table with {line, start_col, end_line, end_col} (0-indexed) or nil.
local function find_anchor_position(bufnr, note)
  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local anchor_lines = note.anchor
  if not anchor_lines or #anchor_lines == 0 then
    return nil
  end

  local function anchor_matches_at(start_line_1based)
    if start_line_1based < 1 or start_line_1based + #anchor_lines - 1 > #buf_lines then
      return false
    end
    for i = 1, #anchor_lines do
      if buf_lines[start_line_1based + i - 1] ~= anchor_lines[i] then
        return false
      end
    end
    return true
  end

  local found_line_1based = nil
  if anchor_matches_at(note.original_start_line) then
    found_line_1based = note.original_start_line
  else
    for i = 1, #buf_lines - #anchor_lines + 1 do
      if anchor_matches_at(i) then
        found_line_1based = i
        break
      end
    end
  end

  if found_line_1based then
    local start_line = found_line_1based - 1
    local end_line = start_line + #anchor_lines - 1
    local start_col = (note.original_start_col or 1) - 1
    local end_col = (#anchor_lines == 1) and (start_col + #anchor_lines[1]) or #anchor_lines[#anchor_lines]
    return { line = start_line, start_col = start_col, end_line = end_line, end_col = end_col }
  end

  return nil
end

---@public
-- Finds all notes and their current positions in the buffer.
function M.find_all_notes_in_buffer(bufnr)
  local located_notes = {}
  local all_notes = M.get_notes_for_buffer(bufnr)
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
-- Gets the notes for the current buffer from the project database.
function M.get_notes_for_buffer(bufnr)
  local persistence_path = paths.get_persistence_filepath(bufnr)
  if not persistence_path then return {} end

  local project_notes = persistence.load(persistence_path)
  if not project_notes then return {} end

  local current_file = vim.api.nvim_buf_get_name(bufnr)
  return project_notes[current_file] or {}
end

---@private
-- A generic function to perform note modifications.
---@param bufnr integer
---@param modification_fcn function A function that takes a list of notes and returns a modified list.
local function perform_modification(bufnr, modification_fcn)
  local persistence_path = paths.get_persistence_filepath(bufnr)
  if not persistence_path then return end

  local project_notes = persistence.load(persistence_path) or {}
  local current_file = vim.api.nvim_buf_get_name(bufnr)
  local current_notes = project_notes[current_file] or {}

  local modified_notes, success = modification_fcn(current_notes)

  if success then
    if not modified_notes or #modified_notes == 0 then
      project_notes[current_file] = nil
    else
      project_notes[current_file] = modified_notes
    end
    persistence.save(project_notes, persistence_path)

    local located_notes = M.find_all_notes_in_buffer(bufnr)
    ui.update_display(bufnr, located_notes)
  end
end

---@public
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
    if start_line <= (note.pos.end_line + 1) and (note.pos.line + 1) <= end_line then
      vim.notify('Sidenote: Cannot create a note that overlaps with an existing one.', vim.log.levels.ERROR)
      return
    end
  end

  vim.ui.input({ prompt = 'Sidenote: ' }, function(note_text)
    if not note_text or note_text == '' then
      vim.notify('Sidenote: Note creation cancelled.', vim.log.levels.INFO)
      return
    end

    perform_modification(bufnr, function(notes)
      local new_note = {
        id = os.date('!%Y-%m-%dT%H:%M:%SZ') .. '-' .. tostring(math.random()),
        original_start_line = start_line,
        original_start_col = start_col,
        original_end_line = end_line,
        original_end_col = end_col,
        text = note_text,
        anchor = anchor_text,
      }
      table.insert(notes, new_note)
      vim.notify('Sidenote: Note saved successfully!')
      return notes, true
    end)
  end)
end

---@public
function M.delete_note_at_cursor()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local located_notes = M.find_all_notes_in_buffer(bufnr)
  if #located_notes == 0 then return end

  local note_to_delete_id = nil
  for _, note in ipairs(located_notes) do
    if cursor_line >= (note.pos.line + 1) and cursor_line <= (note.pos.end_line + 1) then
      note_to_delete_id = note.id
      break
    end
  end

  if not note_to_delete_id then
    vim.notify('Sidenote: No note found at cursor position.', vim.log.levels.INFO)
    return
  end

  perform_modification(bufnr, function(notes)
    local updated_notes = {}
    for _, note in ipairs(notes) do
      if note.id ~= note_to_delete_id then
        table.insert(updated_notes, note)
      end
    end
    vim.notify('Sidenote: Note deleted successfully.')
    return updated_notes, true
  end)
end

---@public
function M.edit_note_at_cursor()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local located_notes = M.find_all_notes_in_buffer(bufnr)
  if #located_notes == 0 then return end

  local note_to_edit = nil
  for _, note in ipairs(located_notes) do
    if cursor_line >= (note.pos.line + 1) and cursor_line <= (note.pos.end_line + 1) then
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

    perform_modification(bufnr, function(notes)
      for i, note in ipairs(notes) do
        if note.id == note_to_edit.id then
          notes[i].text = new_text
          break
        end
      end
      vim.notify('Sidenote: Note updated successfully.')
      return notes, true
    end)
  end)
end

---@public
function M.delete_all_notes_for_buffer()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  perform_modification(bufnr, function(_)
    vim.notify('Sidenote: All notes for this buffer have been deleted.')
    return {}, true -- Return an empty table to delete all notes for this file
  end)
end

return M