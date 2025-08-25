-- lua/sidenote/init.lua

local config_module = require('sidenote.config')

local M = {}

M.config = {}

local function deep_merge(t1, t2)
  for k, v in pairs(t2) do
    if type(v) == 'table' and type(t1[k]) == 'table' then
      deep_merge(t1[k], v)
    else
      t1[k] = v
    end
  end
  return t1
end

local function setup_keymaps(config)
  if not config.enabled then
    return
  end
  local notes = require('sidenote.notes')

  local create_keymap = config.keymap.create_note
  if create_keymap then
    vim.keymap.set('v', create_keymap, notes.create_note, {
      noremap = true,
      silent = true,
      desc = 'Sidenote: Create a note for the selected text',
    })
  end

  local delete_keymap = config.keymap.delete_note
  if delete_keymap then
    vim.keymap.set('n', delete_keymap, notes.delete_note_at_cursor, {
      noremap = true,
      silent = true,
      desc = 'Sidenote: Delete the note at the cursor position',
    })
  end

  local edit_keymap = config.keymap.edit_note
  if edit_keymap then
    vim.keymap.set('n', edit_keymap, notes.edit_note_at_cursor, {
      noremap = true,
      silent = true,
      desc = 'Sidenote: Edit the note at the cursor position',
    })
  end

  local list_keymap = config.keymap.list_notes
  if list_keymap then
    vim.keymap.set('n', list_keymap, function()
      require('sidenote').list_notes()
    end, {
      noremap = true,
      silent = true,
      desc = 'Sidenote: List all notes in the project',
    })
  end
end

local function setup_autocmds(config, ui_manager)
  local notes = require('sidenote.notes')
  local group = vim.api.nvim_create_augroup('SidenoteGroup', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufRead', 'BufWinEnter', 'BufWritePost' }, {
    group = group,
    pattern = '*',
    callback = function(args)
      if not M.config.enabled then
        ui_manager:clear(args.buf)
        return
      end

      if not vim.tbl_contains(config.filetypes, vim.bo[args.buf].filetype) then
        return
      end

      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          local located_notes = notes.find_all_notes_in_buffer(args.buf)
          ui_manager:update(args.buf, located_notes)
        end
      end, 100)
    end,
  })
end

local function setup_commands(ui_manager)
  local notes = require('sidenote.notes')
  vim.api.nvim_create_user_command('SidenoteDeleteAll', notes.delete_all_notes_for_buffer, {})

  vim.api.nvim_create_user_command('SidenoteToggle', function()
    M.config.enabled = not M.config.enabled
    local status = M.config.enabled and 'enabled' or 'disabled'
    vim.notify('Sidenote has been ' .. status .. '.')

    local bufnr = vim.api.nvim_get_current_buf()
    if M.config.enabled then
      local located_notes = notes.find_all_notes_in_buffer(bufnr)
      ui_manager:update(bufnr, located_notes)
    else
      ui_manager:clear(bufnr)
    end
  end, {})

  vim.api.nvim_create_user_command('SidenoteList', function()
    require('sidenote').list_notes()
  end, {})
end

function M.create_ui_manager(config)
  local ui_manager_module = require('sidenote.ui.manager')
  local providers = {}

  -- Create providers based on method
  if config.ui.method == 'virtual_text' or config.ui.method == 'both' then
    local virtual_text = require('sidenote.ui.virtual_text')
    table.insert(providers, virtual_text)
  end

  if config.ui.method == 'signs' or config.ui.method == 'both' then
    local signs = require('sidenote.ui.signs')
    table.insert(providers, signs)
  end

  -- Create composite provider if multiple providers
  local composite_provider = {
    setup = function()
      for _, provider in ipairs(providers) do
        if provider.setup then provider.setup() end
      end
    end,
    update_display = function(bufnr, notes)
      for _, provider in ipairs(providers) do
        if provider.update_display then provider.update_display(bufnr, notes) end
      end
    end,
    clear_display = function(bufnr)
      for _, provider in ipairs(providers) do
        if provider.clear_display then provider.clear_display(bufnr) end
      end
    end,
    cleanup = function()
      for _, provider in ipairs(providers) do
        if provider.cleanup then provider.cleanup() end
      end
    end
  }

  return ui_manager_module.new(composite_provider)
end

function M.setup(opts)
  M.config = vim.deepcopy(config_module.defaults)
  if opts then
    M.config = deep_merge(M.config, opts)
  end

  -- Create UI manager based on configuration
  local ui_manager = M.create_ui_manager(M.config)

  -- Initialize UI providers
  ui_manager:setup()

  -- Inject UI manager into notes module
  local notes = require('sidenote.notes')
  notes.set_ui_manager(ui_manager)

  setup_autocmds(M.config, ui_manager)
  setup_keymaps(M.config)
  setup_commands(ui_manager)

  -- Store UI manager for later use
  M.ui_manager = ui_manager
end

---@public
-- Entry point for the Telescope picker.
function M.list_notes()
  local telescope_ok, _ = pcall(require, 'telescope')
  if not telescope_ok then
    vim.notify(
      'Sidenote: Telescope integration requires "nvim-telescope/telescope.nvim" to be installed.',
      vim.log.levels.WARN
    )
    return
  end
  require('sidenote.telescope').list_all_notes()
end

return M