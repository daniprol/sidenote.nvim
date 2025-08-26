-- lua/sidenote/notes.lua

local sidenote = require('sidenote')
local paths = require('sidenote.paths')
local ui = require('sidenote.ui')

local M = {}

---
-- Gets the visual selection range and text.
-- @return integer, integer, integer, integer, string[]|nil
local function get_visual_selection()
  local _, start_row, start_col, _ = unpack(vim.fn.getpos("'<"))
  local _, end_row, end_col, _ = unpack(vim.fn.getpos("'>"))
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

  -- Extract the exact selected text based on columns
  if #lines == 1 then
    -- Single line selection
    local line = lines[1]
    local selected_text = line:sub(start_col, end_col)
    return start_row, start_col, end_row, end_col, {selected_text}
  else
    -- Multi-line selection
    local result = {}
    for i, line in ipairs(lines) do
      if i == 1 then
        -- First line: from start_col to end
        result[i] = line:sub(start_col)
      elseif i == #lines then
        -- Last line: from start to end_col
        result[i] = line:sub(1, end_col)
      else
        -- Middle lines: full line
        result[i] = line
      end
    end
    return start_row, start_col, end_row, end_col, result
  end
end

---
-- Finds the current position of a note's anchor text in the buffer.
-- @param bufnr integer The buffer to search in.
-- @param note table The note object with its anchor text.
-- @return integer|nil, integer|nil, integer|nil The line number (1-based), start_col (0-based), end_col (0-based) or nil if not found.
local function find_anchor_position(bufnr, note)
  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local anchor_lines = note.anchor
  if not anchor_lines then return nil end
  local num_buf_lines = #buf_lines
  local num_anchor_lines = #anchor_lines

  if num_anchor_lines == 0 then
    return nil
  end

  -- For now, handle single-line anchors (most common case)
  if num_anchor_lines == 1 then
    local anchor_text = anchor_lines[1]
    local config = require('sidenote').config

    if config.debug then
      print(string.format("DEBUG: Looking for anchor text: '%s'", anchor_text))
    end

    for i = 0, num_buf_lines - 1 do
      local line = buf_lines[i + 1]
      local start_col = string.find(line, anchor_text, 1, true)

      if config.debug then
        print(string.format("DEBUG: Checking line %d: '%s', found at col %s", i + 1, line, tostring(start_col)))
      end

      if start_col then
        local end_col = start_col + #anchor_text - 1
        if config.debug then
          print(string.format("DEBUG: Found anchor at line %d, cols %d-%d (0-indexed: %d-%d)",
            i + 1, start_col, end_col, start_col - 1, end_col))
        end
        return i + 1, start_col - 1, end_col  -- Convert to 0-based columns
      end
    end

    if config.debug then
      print("DEBUG: Anchor text not found in buffer")
    end
  else
    -- For multi-line anchors, find the starting line
    for i = 0, num_buf_lines - num_anchor_lines do
      local match = true
      for j = 1, num_anchor_lines do
        if buf_lines[i + j] ~= anchor_lines[j] then
          match = false
          break
        end
      end
      if match then
        -- For multi-line, use original column positions if available
        local start_col = note.original_start_col and (note.original_start_col - 1) or 0
        local end_col = note.original_end_col and (note.original_end_col - 1) or #buf_lines[i + 1]
        return i + 1, start_col, end_col
      end
    end
  end

  return nil
end

---
-- Prompts user for a note and saves it for the current visual selection.
function M.create_note()
  if not sidenote.config.enabled then return end
  local start_line, start_col, end_line, end_col, anchor_text = get_visual_selection()
  if not anchor_text or #anchor_text == 0 then
    vim.notify('Sidenote: No visual selection found.', vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = 'Sidenote: ' }, function(note_text)
    if not note_text or note_text == '' then
      vim.notify('Sidenote: Note creation cancelled.', vim.log.levels.INFO)
      return
    end

    if string.len(note_text) > sidenote.config.max_char_count then
      vim.notify(
        string.format('Sidenote: Note exceeds max length of %d', sidenote.config.max_char_count),
        vim.log.levels.WARN
      )
      return
    end

    local bufnr = vim.api.nvim_get_current_buf()
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

     local dir = vim.fn.fnamemodify(note_filepath, ':h')
     vim.fn.mkdir(dir, 'p')

     vim.fn.writefile({ 'return ' .. vim.inspect(all_notes) }, note_filepath)
     vim.notify('Sidenote: Note saved successfully!')

     -- Update UI display
     local located_notes = M.find_all_notes_in_buffer(bufnr)
     ui.update_display(bufnr, located_notes)
  end)
end

---
-- Finds all notes and their current positions in the buffer.
-- @param bufnr integer The buffer number.
-- @return table A list of note objects, each with 'current_line', 'current_start_col', 'current_end_col' keys.
function M.find_all_notes_in_buffer(bufnr)
  local located_notes = {}
  local all_notes = M.parse_notes_for_buffer(bufnr)
  if not all_notes then
    return located_notes
  end

  for _, note in ipairs(all_notes) do
    local current_line, current_start_col, current_end_col = find_anchor_position(bufnr, note)
    if current_line then
      note.current_line = current_line
      note.current_start_col = current_start_col
      note.current_end_col = current_end_col
      table.insert(located_notes, note)
    end
  end

  return located_notes
end

---
-- Deletes the note found at the current cursor position.
function M.delete_note_at_cursor()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local located_notes = M.find_all_notes_in_buffer(bufnr)
  if #located_notes == 0 then
    vim.notify('Sidenote: No notes found in this file.', vim.log.levels.INFO)
    return
  end

  local note_to_delete_id = nil
  for _, note in ipairs(located_notes) do
    local note_start_line = note.current_line
    local note_end_line = note_start_line + #note.anchor - 1
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
   vim.fn.writefile({ 'return ' .. vim.inspect(updated_notes) }, note_filepath)

   vim.notify('Sidenote: Note deleted successfully.')

   -- Update UI display
   local located_notes = M.find_all_notes_in_buffer(bufnr)
   ui.update_display(bufnr, located_notes)
end

---
-- Finds and prompts to update a note at the current cursor position.
function M.edit_note_at_cursor()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local located_notes = M.find_all_notes_in_buffer(bufnr)
  if #located_notes == 0 then
    vim.notify('Sidenote: No notes found in this file.', vim.log.levels.INFO)
    return
  end

  local note_to_edit = nil
  for _, note in ipairs(located_notes) do
    local note_start_line = note.current_line
    local note_end_line = note_start_line + #note.anchor - 1
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
      vim.notify(
        string.format('Sidenote: Note exceeds max length of %d', sidenote.config.max_char_count),
        vim.log.levels.WARN
      )
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
     vim.fn.writefile({ 'return ' .. vim.inspect(all_notes_raw) }, note_filepath)

     vim.notify('Sidenote: Note updated successfully.')

     -- Update UI display
     local located_notes = M.find_all_notes_in_buffer(bufnr)
     ui.update_display(bufnr, located_notes)
  end)
end

---
-- Deletes all notes for the current buffer.
function M.delete_all_notes_for_buffer()
  if not sidenote.config.enabled then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local note_filepath = paths.get_note_filepath(bufnr)

   if note_filepath and vim.fn.filereadable(note_filepath) == 1 then
     os.remove(note_filepath)
     vim.notify('Sidenote: All notes for this buffer have been deleted.')

     -- Clear UI display
     ui.clear_display(bufnr)
   else
     vim.notify('Sidenote: No notes found for this buffer.', vim.log.levels.INFO)
   end
end

---
-- Parses the note file for a given buffer.
-- @param bufnr integer The buffer number.
-- @return table|nil The parsed notes table or nil.
function M.parse_notes_for_buffer(bufnr)
  local note_filepath = paths.get_note_filepath(bufnr)
  return M.parse_notes_from_file(note_filepath)
end

---
-- Parses a note file from a given filepath.
-- @param filepath string The path to the note file.
-- @return table|nil The parsed notes table or nil.
function M.parse_notes_from_file(filepath)
  if not filepath or vim.fn.filereadable(filepath) == 0 then
    return nil
  end

  local notes_content, _ = vim.fn.readfile(filepath)
  if not notes_content or #notes_content == 0 then
    return nil
  end

  local func, err = load(table.concat(notes_content, '\n'))
  if func then
    local success, result = pcall(func)
    if success then
      return result
    end
  end
  vim.notify(string.format('Sidenote: Error parsing notes file %s: %s', filepath, tostring(err)), vim.log.levels.ERROR)
  return nil
end

return M
