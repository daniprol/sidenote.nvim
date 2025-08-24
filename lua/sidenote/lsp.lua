-- lua/sidenote/lsp.lua

local sidenote = require('sidenote')
local notes = require('sidenote.notes')

local M = {}

local namespace = vim.api.nvim_create_namespace('sidenote')

---@public
-- Updates the diagnostics for a given buffer.
---@param bufnr integer The buffer number to update.
function M.update_diagnostics(bufnr)
  M.clear_diagnostics(bufnr)

  -- Do not show diagnostics if the plugin is disabled
  if not sidenote.config.enabled then
    return
  end

  local located_notes = notes.find_all_notes_in_buffer(bufnr)
  if not located_notes or #located_notes == 0 then
    return
  end

  local diagnostics = {}
  local severity = vim.diagnostic.severity[sidenote.config.diagnostic_severity]

  for _, note in ipairs(located_notes) do
    table.insert(diagnostics, {
      bufnr = bufnr,
      lnum = note.current_line - 1, -- LSP diagnostics are 0-indexed
      col = 0, -- Start of the line
      severity = severity,
      message = note.text,
      source = 'sidenote',
    })
  end

  if #diagnostics > 0 then
    vim.diagnostic.set(namespace, bufnr, diagnostics, {})
  end
end

---@public
-- Clears all sidenote diagnostics for a given buffer.
---@param bufnr integer The buffer number to clear.
function M.clear_diagnostics(bufnr)
  vim.diagnostic.hide(namespace, bufnr)
end

return M