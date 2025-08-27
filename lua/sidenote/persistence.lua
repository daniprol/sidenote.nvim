-- lua/sidenote/persistence.lua

local M = {}

---Saves the entire project notes database to a single JSON file.
---@param project_notes table The table of all project notes.
---@param filepath string The absolute path to the file.
function M.save(project_notes, filepath)
  -- To ensure stable git diffs, we must write the top-level keys (file paths)
  -- in a sorted order.
  local sorted_keys = {}
  for key, _ in pairs(project_notes) do
    table.insert(sorted_keys, key)
  end
  table.sort(sorted_keys)

  local ordered_notes = {}
  for _, key in ipairs(sorted_keys) do
    ordered_notes[key] = project_notes[key]
  end

  -- Encode the newly ordered table. The `luanil` option handles empty tables correctly.
  local json_string = vim.fn.json_encode(ordered_notes)

  local dir = vim.fn.fnamemodify(filepath, ':h')
  vim.fn.mkdir(dir, 'p')
  vim.fn.writefile({ json_string }, filepath)
end

---Loads the project notes database from a single JSON file.
---@param filepath string The absolute path to the file.
---@return table|nil The loaded database, or nil if an error occurs.
function M.load(filepath)
  if not filepath or vim.fn.filereadable(filepath) == 0 then
    return {}
  end

  local json_string, _ = vim.fn.readfile(filepath)
  if not json_string or #json_string == 0 then
    return {}
  end

  local content = table.concat(json_string, '\n')
  if content == '' then
    return {}
  end

  local success, result = pcall(vim.fn.json_decode, content)

  if success then
    return result
  else
    vim.notify('Sidenote: Error decoding JSON from ' .. filepath, vim.log.levels.ERROR)
    return nil
  end
end

return M
