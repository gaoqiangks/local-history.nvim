local Path = require("local_history.path")

local M = {}

local function notify(msg, level, cfg)
  if cfg.notify then
    vim.notify(msg, level or vim.log.levels.INFO, { title = "local-history" })
  end
end

local function should_exclude(file_abs, cfg)
  for _, p in ipairs(cfg.exclude_patterns or {}) do
    if file_abs:match(p) then
      return true
    end
  end

  local stat = vim.loop.fs_stat(file_abs)
  if stat and stat.size and cfg.max_file_size_kb then
    if stat.size > cfg.max_file_size_kb * 1024 then
      return true
    end
  end

  return false
end

local function read_file_content(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return table.concat(lines, "\n")
end

local function write_file(path, content)
  local fd = assert(io.open(path, "w"))
  fd:write(content)
  fd:close()
end

local function list_snapshots(dir)
  local files = vim.fn.globpath(dir, "*.snap", false, true) or {}
  table.sort(files)
  return files
end

local function latest_snapshot(dir)
  local snaps = list_snapshots(dir)
  return snaps[#snaps]
end

local function cleanup_old(dir, max_entries)
  if not max_entries or max_entries <= 0 then
    return
  end
  local snaps = list_snapshots(dir)
  local extra = #snaps - max_entries
  if extra <= 0 then
    return
  end
  for i = 1, extra do
    pcall(vim.loop.fs_unlink, snaps[i])
  end
end

function M.snapshot_current_file(file_abs, cfg)
  if not cfg.enabled or file_abs == "" then
    return
  end
  file_abs = Path.normalize(file_abs)

  if should_exclude(file_abs, cfg) then
    return
  end

  local root = Path.workspace_root(file_abs)
  local rel = Path.relpath(file_abs, root)
  local dir = Path.file_dir(cfg.root_dir, root, rel)
  Path.ensure_dir(dir)

  local content = read_file_content(file_abs)
  if content == nil then
    return
  end

  local last = latest_snapshot(dir)
  if last then
    local prev = read_file_content(last)
    if prev == content then
      return
    end
  end

  local snap = dir .. "/" .. Path.timestamp_name()
  write_file(snap, content)
  cleanup_old(dir, cfg.max_entries_per_file)
end

function M.list_for_file(file_abs, cfg)
  file_abs = Path.normalize(file_abs)
  local root = Path.workspace_root(file_abs)
  local rel = Path.relpath(file_abs, root)
  local dir = Path.file_dir(cfg.root_dir, root, rel)
  return list_snapshots(dir)
end

function M.read_snapshot(path)
  return read_file_content(path)
end

function M.restore_to_current_buffer(snapshot_path)
  local content = M.read_snapshot(snapshot_path)
  if not content then
    return false, "failed to read snapshot"
  end
  local lines = vim.split(content, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.modified = true
  return true
end

M.notify = notify
return M
