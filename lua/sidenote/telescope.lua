-- lua/sidenote/telescope.lua

local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local conf = require("telescope.config").values

local paths = require('sidenote.paths')
local notes = require('sidenote.notes')

local M = {}

---@private
-- Converts a note file path back to its original source file path.
---@param note_filepath string Path to the .sn file.
---@param notes_root string Path to the .sidenotes directory.
---@return string Path to the original source file.
local function note_path_to_source_path(note_filepath, notes_root)
  local sidenote_config = require('sidenote').config
  local relative_path = note_filepath:sub(#notes_root + 2)
  local source_relative_path = relative_path:sub(1, #relative_path - #sidenote_config.note_file_extension)
  return paths.get_project_root(0) .. '/' .. source_relative_path
end

---@public
-- Opens a Telescope picker to list all notes in the project.
function M.list_all_notes()
  local sidenote_config = require('sidenote').config
  local project_root = paths.get_project_root(0)
  if not project_root then
    vim.notify("Sidenote: Could not determine project root.", vim.log.levels.WARN)
    return
  end

  local notes_dir = project_root .. '/' .. sidenote_config.notes_dir_name
  if vim.fn.isdirectory(notes_dir) == 0 then
    vim.notify("Sidenote: No notes found in this project.", vim.log.levels.INFO)
    return
  end

  local all_note_files = vim.fs.find(function(name, path)
    return name:match('.*' .. sidenote_config.note_file_extension .. '$')
  end, { path = notes_dir, type = 'file' })

  local results = {}
  for _, note_file in ipairs(all_note_files) do
    local parsed_notes = notes.parse_notes_from_file(note_file)
    if parsed_notes then
      local source_file = note_path_to_source_path(note_file, notes_dir)
      for _, note in ipairs(parsed_notes) do
        table.insert(results, {
          filename = source_file,
          lnum = note.original_start_line,
          text = note.text,
          display = string.format("%s:%d: %s", vim.fn.fnamemodify(source_file, ':.'), note.original_start_line, note.text),
        })
      end
    end
  end

  pickers.new({}, {
    prompt_title = "Project Sidenotes",
    finder = finders.new_table {
      results = results,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.display,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.cmd(string.format("edit %s", selection.value.filename))
        vim.api.nvim_win_set_cursor(0, { selection.value.lnum, 0 })
      end)
      return true
    end,
  }):find()
end

return M
