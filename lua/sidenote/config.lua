-- lua/sidenote/config.lua

local M = {}

M.defaults = {
  -- The maximum number of characters allowed in a note.
  max_char_count = 150,

  -- Keymap for creating a note from a visual selection.
  keymap = {
    create_note = '<leader>sa',
    delete_note = '<leader>sd',
    edit_note = '<leader>se',
    list_notes = '<leader>sl',
  },

  -- The name of the single file where all notes for a project are stored.
  persistence_file = '.sidenotes.json',

  -- Virtual text configuration
  virtual_text = {
    -- Position: 'eol', 'right_align', 'overlay', 'inline'
    position = 'eol',
    -- Prefix for virtual text
    prefix = '📝',
    -- Maximum length of displayed note text
    max_length = 50,
  },

  -- Whether to show signs in the sign column
  signs_enabled = false,

  -- Emoji for sign column when signs are enabled
  sign_emoji = '📝',

  -- Anchor text highlighting configuration
  anchor_highlight = {
    -- Whether to highlight anchor text
    enabled = true,
    -- Default highlight group for anchor text
    default_hl = 'SidenoteAnchor',
    -- Highlight group when cursor is over anchor text
    active_hl = 'SidenoteAnchorActive',
    -- Priority for anchor highlights (lower than virtual text)
    priority = 50,
  },

  -- Debug mode (set to true to enable debug logging)
  debug = false,

  -- A list of filetypes for which the plugin should be active.
  filetypes = { 'markdown', 'txt' },

  -- The plugin is enabled by default. Use :SidenoteToggle to change.
  enabled = true,
}

return M
