-- lua/sidenote/paths.lua

local sidenote = require('sidenote')
local M = {}

-- Memoization cache for found root directories
local root_cache = {}

---@private
--- Finds the project root based on the presence of a .git directory.
---@param path string The starting path to search from.
---@return string|nil The git root path or nil if not found.
local function find_git_root(path)
  local git_dir = vim.fs.find('.git', { path = path, upward = true, type = 'directory' })
  if #git_dir > 0 then
    return vim.fn.fnamemodify(git_dir[1], ':h')
  end
  return nil
end

---@private
--- Finds an existing .sidenotes directory by searching upwards from a path.
---@param path string The starting path to search from.
---@return string|nil The path of the project containing .sidenotes or nil.
local function find_existing_sidenotes_root(path)
  local notes_dir_name = sidenote.config.notes_dir_name
  local sidenotes_dir = vim.fs.find(notes_dir_name, { path = path, upward = true, type = 'directory' })
  if #sidenotes_dir > 0 then
    return vim.fn.fnamemodify(sidenotes_dir[1], ':h')
  end
  return nil
end

---@public
--- Gets the root directory for the .sidenotes folder based on the heuristics.
---@param bufnr integer The buffer number to find the root for.
---@return string|nil The absolute path to the project root, or nil on error.
function M.get_project_root(bufnr)
  local buf_path = vim.api.nvim_buf_get_name(bufnr)
  if not buf_path or buf_path == '' then
    return nil
  end

  if root_cache[bufnr] then
    return root_cache[bufnr]
  end

  local current_dir = vim.fn.fnamemodify(buf_path, ':h')

  -- Heuristic 1: Find git repo root
  local git_root = find_git_root(current_dir)
  if git_root then
    root_cache[bufnr] = git_root
    return git_root
  end

  -- Heuristic 2: Find existing .sidenotes directory
  local existing_root = find_existing_sidenotes_root(current_dir)
  if existing_root then
    root_cache[bufnr] = existing_root
    return existing_root
  end

  -- Heuristic 3: Default to the current file's directory
  root_cache[bufnr] = current_dir
  return current_dir
end

---@public
--- Constructs the full path for a note file corresponding to a buffer.
---@param bufnr integer The buffer number.
---@return string|nil The full path to the note file, or nil on error.
function M.get_note_filepath(bufnr)
  local project_root = M.get_project_root(bufnr)
  local buf_path = vim.api.nvim_buf_get_name(bufnr)

  if not project_root or not buf_path or buf_path == '' then
    return nil
  end

  local relative_buf_path = vim.fn.fnamemodify(buf_path, ':~')
  if project_root then 
    relative_buf_path = string.sub(buf_path, #project_root + 2)
  end

  local notes_dir = sidenote.config.notes_dir_name
  local note_ext = sidenote.config.note_file_extension

  return table.concat({
    project_root,
    notes_dir,
    relative_buf_path .. note_ext,
  }, '/')
end

return M
