-- lua/sidenote/config.lua

local M = {}

M.defaults = {
  -- The maximum number of characters allowed in a note.
  max_char_count = 150,

  -- Keymap for creating a note from a visual selection.
  keymap = {
    create_note = '<leader>s',
    delete_note = '<leader>sx',
    edit_note = '<leader>se',
    list_notes = '<leader>sl',
  },

  -- The name of the directory where all notes are stored.
  notes_dir_name = '.sidenotes',

  -- The file extension for individual note files.
  -- e.g., 'main.lua' -> 'main.lua.sn'
  note_file_extension = '.sn',

  -- Diagnostic severity for the notes.
  -- Can be: 'ERROR', 'WARN', 'INFO', 'HINT'
  diagnostic_severity = 'INFO',

  -- A list of filetypes for which the plugin should be active.
  filetypes = { 'markdown', 'txt' },

  -- The plugin is enabled by default. Use :SidenoteToggle to change.
  enabled = true,
}

return M
