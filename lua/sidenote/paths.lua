-- lua/sidenote/paths.lua

local sidenote = require('sidenote')
local M = {}

local root_cache = {}

local function find_git_root(path)
  local git_dir = vim.fs.find('.git', { path = path, upward = true, type = 'directory' })
  if #git_dir > 0 then
    return vim.fn.fnamemodify(git_dir[1], ':h')
  end
  return nil
end

function M.get_project_root(bufnr)
  local buf_path = vim.api.nvim_buf_get_name(bufnr)
  if not buf_path or buf_path == '' then
    return nil
  end

  if root_cache[bufnr] then
    return root_cache[bufnr]
  end

  local current_dir = vim.fn.fnamemodify(buf_path, ':h')

  local git_root = find_git_root(current_dir)
  if git_root then
    root_cache[bufnr] = git_root
    return git_root
  end

  -- For non-git projects, the root is simply the directory of the current file.
  -- The .sidenotes.json file will be created here.
  root_cache[bufnr] = current_dir
  return current_dir
end

---@public
--- Constructs the full path to the project's single persistence file.
---@param bufnr integer The buffer number.
---@return string|nil The full path to the .sidenotes.json file, or nil on error.
function M.get_persistence_filepath(bufnr)
  local project_root = M.get_project_root(bufnr)
  if not project_root then
    return nil
  end

  return project_root .. '/' .. sidenote.config.persistence_file
end

return M