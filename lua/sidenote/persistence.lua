-- lua/sidenote/persistence.lua

local M = {}

---Saves a table of notes to a specified filepath in JSON format.
---@param notes_table table The table of notes to save.
---@param filepath string The absolute path to the file.
function M.save(notes_table, filepath)
  local json_string = vim.fn.json_encode(notes_table)
  -- The json_encode function produces a single line. For readability, we can
  -- attempt to format it, but for now, we will write it as is.
  -- A future improvement could be to use an external library for pretty-printing.
  local dir = vim.fn.fnamemodify(filepath, ':h')
  vim.fn.mkdir(dir, 'p')
  vim.fn.writefile({ json_string }, filepath)
end

---Loads a table of notes from a specified JSON filepath.
---@param filepath string The absolute path to the file.
---@return table|nil The loaded table of notes, or nil if an error occurs.
function M.load(filepath)
  if not filepath or vim.fn.filereadable(filepath) == 0 then
    return nil
  end

  local json_string, _ = vim.fn.readfile(filepath)
  if not json_string or #json_string == 0 then
    return nil
  end

  -- readfile returns a list of lines, so concatenate them.
  local content = table.concat(json_string, '\n')

  local success, result = pcall(vim.fn.json_decode, content)

  if success then
    return result
  else
    vim.notify('Sidenote: Error decoding JSON from ' .. filepath, vim.log.levels.ERROR)
    return nil
  end
end

return M