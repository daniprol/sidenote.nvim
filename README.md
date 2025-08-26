# sidenote.nvim

> "The way that you remember things is by trying to remember them."

In a compelling video on how to remember everything you read, [Professor Jeffrey Kaplan explains an effective technique](https://www.youtube.com/watch?v=uiNB-6SuqVA): after reading a passage, force yourself to summarize its core idea in a single sentence in the margin. This act of retrieval is what builds long-term memory.

`sidenote.nvim` is a Neovim plugin designed to bring this powerful learning method directly into your text editor. It allows you to attach your thoughts, summaries, and questions to text as non-intrusive "margin notes," which are displayed as virtual text with optional sign column indicators.

It's a simple tool for a profound purpose: to help you think more deeply and remember more effectively.

![sidenote.nvim demo](https://user-images.githubusercontent.com/2336198/263520003-735133b8-5f31-4a23-935a-5459a559ac2d.gif)
*Demo showing note creation, viewing as virtual text, and listing all notes with Telescope.*

---

## Features

-   ✍️ **Create Notes**: Attach a thought to any block of text using a simple keymap.
-   👀 **Virtual Text Display**: Notes appear as virtual text with customizable positioning and optional sign column indicators.
-   🎯 **Smart Anchor Highlighting**: The exact text you selected when creating a note is highlighted, with enhanced styling when your cursor hovers over it.
-   ✏️ **Full CRUD**: Create, Edit, and Delete notes with simple, intuitive commands.
-   🧠 **Robust Anchoring**: Notes stay attached to their text, even as you add or remove lines above and below them.
-   🔭 **Telescope Integration**: Fuzzy-find and jump to any note in your entire project with `:SidenoteList`.
-   ✅ **Clean File Storage**: Notes are stored in a central `.sidenotes` directory in your project root, keeping your original files completely clean.
-   ⚙️ **Configurable**: Customize keymaps, filetypes, and more.
-    toggles: **Toggle On/Off**: Quickly enable or disable the entire plugin with `:SidenoteToggle`.

## Requirements

-   Neovim >= 0.8.0
-   [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for the `:SidenoteList` command)

## Installation

Install with your favorite package manager.

### lazy.nvim

```lua
{
  -- Make sure to point to your local plugin directory for development
  dir = '/home/daniprol/.config/nvim/sidenote.nvim',
  -- For a real release, you would use:
  -- 'your-username/sidenote.nvim',
  -- version = "0.1.0", -- Optionally pin to a specific version
  config = function()
    require('sidenote').setup({
      -- Your custom options go here
    })
  end,
}
```

## Usage

`sidenote.nvim` is designed to be simple to use out of the box.

### Troubleshooting

If you encounter issues with anchor highlighting (especially at column 0), you can enable debug mode:

```lua
require('sidenote').setup({
  debug = true,  -- Enable debug logging
})
```

This will print debug information to help identify issues with note positioning and anchor text detection.

| Keymap          | Mode   | Description                                |
| --------------- | ------ | ------------------------------------------ |
| `<leader>sn`    | Visual | **S**idenote **N**ew: Create a new note.   |
| `<leader>se`    | Normal | **S**idenote **E**dit: Edit note at cursor.  |
| `<leader>sx`    | Normal | **S**idenote **X** (delete): Delete note at cursor. |
| `<leader>sl`    | Normal | **S**idenote **L**ist: List all project notes (Telescope). |

| Command             | Description                               |
| ------------------- | ----------------------------------------- |
| `:SidenoteList`     | List all notes in the project (Telescope). |
| `:SidenoteDeleteAll`| Delete all notes in the current buffer.   |
| `:SidenoteToggle`   | Globally enable or disable the plugin.    |


## Configuration

You can override any of the default settings by passing a table to the `setup()` function.

Here is the default configuration:

```lua
require('sidenote').setup({
  -- A list of filetypes for which the plugin should be active.
  filetypes = { 'markdown', 'txt' },

  -- The plugin is enabled by default. Use :SidenoteToggle to change.
  enabled = true,

  -- The maximum number of characters allowed in a note.
  max_char_count = 150,

  keymap = {
    create_note = '<leader>sn',
    delete_note = '<leader>sx',
    edit_note = '<leader>se',
    list_notes = '<leader>sl',
  },

  -- The name of the directory where all notes are stored.
  notes_dir_name = '.sidenotes',

  -- The file extension for individual note files.
  note_file_extension = '.sn',

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
})
```