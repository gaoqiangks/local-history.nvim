local M = {}

function M.ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

function M.normalize(path)
  return vim.fs.normalize(path)
end

function M.workspace_root(file_abs)
  local cwd = vim.loop.cwd() or vim.fn.getcwd()
  cwd = M.normalize(cwd)
  if file_abs and vim.startswith(file_abs, cwd) then
    return cwd
  end
  return cwd
end

function M.relpath(file_abs, root)
  file_abs = M.normalize(file_abs)
  root = M.normalize(root)
  if vim.startswith(file_abs, root) then
    local rel = file_abs:sub(#root + 2)
    return rel == "" and vim.fn.fnamemodify(file_abs, ":t") or rel
  end
  return vim.fn.fnamemodify(file_abs, ":t")
end

function M.workspace_hash(root)
  return vim.fn.sha256(root):sub(1, 12)
end

function M.file_dir(root_dir, workspace_root, relpath)
  local ws = M.workspace_hash(workspace_root)
  local dir = root_dir .. "/" .. ws .. "/" .. relpath
  return dir:gsub(":", "_")
end

function M.timestamp_name()
  return os.date("%Y%m%d-%H%M%S") .. ".snap"
end

return M
