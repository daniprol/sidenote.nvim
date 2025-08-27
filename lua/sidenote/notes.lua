-- lua/sidenote/notes.lua

local sidenote = require('sidenote')
local paths = require('sidenote.paths')
local ui = require('sidenote.ui')
local persistence = require('sidenote.persistence')

local M = {}

--#region Private Helper Functions

--- Finds the current position of a note's anchor text in the buffer.
-- @param bufnr (integer) The buffer to search in.
-- @param note (table) The note object, containing the anchor text and original position.
-- @return (table|nil) A position table { line, start_col, end_line, end_col } (0-indexed) or nil.
local function find_anchor_position(bufnr, note)
  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local anchor_lines = note.anchor
  if not anchor_lines or #anchor_lines == 0 then
    return nil
  end

  local function anchor_matches_at(start_line_1based)
    if start_line_1based < 1 or (start_line_1based + #anchor_lines - 1) > #buf_lines then
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

  if not found_line_1based then
    return nil
  end

  local pos = {}
  pos.line = found_line_1based - 1 -- API needs 0-indexed line
  pos.end_line = pos.line + #anchor_lines - 1
  pos.start_col = (note.original_start_col or 1) - 1 -- API needs 0-indexed column

  if #anchor_lines == 1 then
    pos.end_col = pos.start_col + #anchor_lines[1]
  else
    pos.end_col = #anchor_lines[#anchor_lines]
  end

  return pos
end

--- Checks if a new selection range overlaps with any existing notes.
-- @param located_notes (table) A list of notes that have a 'pos' table.
-- @param new_start_line (integer) The 1-based starting line of the new selection.
-- @param new_end_line (integer) The 1-based ending line of the new selection.
-- @return (boolean) True if an overlap is found, false otherwise.
local function check_for_overlap(located_notes, new_start_line, new_end_line)
  for _, note in ipairs(located_notes) do
    -- note.pos contains 0-indexed lines. Convert to 1-based for comparison.
    local existing_start = note.pos.line + 1
    local existing_end = note.pos.end_line + 1

    -- Standard range overlap check: (StartA <= EndB) and (StartB <= EndA)
    if new_start_line <= existing_end and existing_start <= new_end_line then
      return true -- Overlap found
    end
  end
  return false -- No overlap
end

--- A generic function to perform note modifications.
-- @param bufnr (integer)
-- @param modification_fcn (function) A function that takes a list of notes and returns a modified list.
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

--#endregion

--#region Public API Functions

--- Gets all notes for a buffer and finds their current position.
function M.find_all_notes_in_buffer(bufnr)
  local located_notes = {}
  local persistence_path = paths.get_persistence_filepath(bufnr)
  if not persistence_path then return {} end

  local project_notes = persistence.load(persistence_path) or {}
  local current_file = vim.api.nvim_buf_get_name(bufnr)
  local notes_for_file = project_notes[current_file] or {}

  for _, note in ipairs(notes_for_file) do
    local pos = find_anchor_position(bufnr, note)
    if pos then
      note.pos = pos
      table.insert(located_notes, note)
    end
  end
  return located_notes
end

--- Prompts user for a note and saves it for the current visual selection.
function M.create_note()
  if not sidenote.config.enabled then return end

  -- getpos() returns 1-based coordinates.
  local _, start_line, start_col, _ = unpack(vim.fn.getpos("'<"))
  local _, end_line, end_col, _ = unpack(vim.fn.getpos("'>"))
  local buffer_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  local anchor_text
  if #buffer_lines == 1 then
    anchor_text = { buffer_lines[1]:sub(start_col, end_col) }
  else
    anchor_text = {}
    for i, line in ipairs(buffer_lines) do
      if i == 1 then table.insert(anchor_text, line:sub(start_col)) end
      if i > 1 and i < #buffer_lines then table.insert(anchor_text, line) end
      if i == #buffer_lines and i > 1 then table.insert(anchor_text, line:sub(1, end_col)) end
    end
  end

  if not anchor_text or #anchor_text == 0 then
    vim.notify('Sidenote: No visual selection found.', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local existing_notes = M.find_all_notes_in_buffer(bufnr)

  -- Use the clean helper function to check for overlaps.
  if check_for_overlap(existing_notes, start_line, end_line) then
    vim.notify('Sidenote: Cannot create a note that overlaps with an existing one.', vim.log.levels.ERROR)
    return
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

--- Deletes the note found at the current cursor position.
function M.delete_note_at_cursor()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] -- This is 1-based

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

--- Finds and prompts to update a note at the current cursor position.
function M.edit_note_at_cursor()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] -- This is 1-based

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

--- Deletes all notes for the current buffer.
function M.delete_all_notes_for_buffer()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  perform_modification(bufnr, function(_)
    vim.notify('Sidenote: All notes for this buffer have been deleted.')
    return {}, true -- Return an empty table to delete all notes for this file
  end)
end

--#endregion

return M