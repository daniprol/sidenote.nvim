-- lua/sidenote/telescope.lua

local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local conf = require("telescope.config").values

local paths = require('sidenote.paths')
local persistence = require('sidenote.persistence')

local M = {}

---@public
-- Opens a Telescope picker to list all notes in the project.
function M.list_all_notes()
  local persistence_path = paths.get_persistence_filepath(0)
  if not persistence_path then
    vim.notify("Sidenote: Could not determine project root.", vim.log.levels.WARN)
    return
  end

  local project_notes = persistence.load(persistence_path)
  if not project_notes or vim.tbl_isempty(project_notes) then
    vim.notify("Sidenote: No notes found in this project.", vim.log.levels.INFO)
    return
  end

  local results = {}
  for filepath, notes in pairs(project_notes) do
    for _, note in ipairs(notes) do
      table.insert(results, {
        filename = filepath,
        lnum = note.original_start_line,
        text = note.text,
        display = string.format("%s:%d: %s", vim.fn.fnamemodify(filepath, ':.'), note.original_start_line, note.text),
      })
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