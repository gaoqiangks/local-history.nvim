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
  if file_abs and vim.startswith(M.normalize(file_abs), cwd) then
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
  -- VS Code local-history style: .history/<filename>/ in the same directory as the file
  -- root_dir is ignored, we always use .history
  -- Build the absolute path to the file's directory
  local file_abs = workspace_root .. "/" .. relpath
  file_abs = M.normalize(file_abs)
  local file_dir_path = vim.fn.fnamemodify(file_abs, ":p:h")
  local file_name = vim.fn.fnamemodify(file_abs, ":t")
  -- The history directory is <file_dir_path>/.history/<file_name>/
  local history_dir = file_dir_path .. "/.history/" .. file_name
  return history_dir
end

function M.timestamp_name()
  -- VS Code local-history uses format like 20250101-120000
  return os.date("%Y%m%d-%H%M%S")
end

function M.meta_file(dir)
  return dir .. "/index.json"
end

return M
