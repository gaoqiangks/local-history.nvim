local Path = require("local_history.path")
local Util = require("local_history.util")

local M = {}

local function notify(msg, level, cfg)
  if cfg.notify then
    vim.notify(msg, level or vim.log.levels.INFO, { title = "local-history" })
  end
end

local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return table.concat(lines, "\n")
end

local function write_file(path, content)
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
end

local function list_snapshots(dir)
  local files = vim.fn.globpath(dir, "*.snap", false, true) or {}
  table.sort(files)
  return files
end

local function should_exclude(file_abs, cfg)
  for _, p in ipairs(cfg.exclude_patterns or {}) do
    if file_abs:match(p) then
      return true
    end
  end

  local st = vim.loop.fs_stat(file_abs)
  if st and st.size and cfg.max_file_size_kb then
    if st.size > cfg.max_file_size_kb * 1024 then
      return true
    end
  end

  if cfg.skip_binary and Util.is_binary(file_abs) then
    return true
  end

  return false
end

local function load_index(dir)
  return Util.read_json(Path.meta_file(dir)) or { snapshots = {} }
end

local function save_index(dir, idx)
  Util.write_json(Path.meta_file(dir), idx)
end

local function append_index(dir, entry)
  local idx = load_index(dir)
  idx.snapshots = idx.snapshots or {}
  table.insert(idx.snapshots, entry)
  save_index(dir, idx)
end

local function prune_index_missing_files(dir)
  local idx = load_index(dir)
  local kept = {}
  for _, e in ipairs(idx.snapshots or {}) do
    if e.file and Util.file_exists(dir .. "/" .. e.file) then
      table.insert(kept, e)
    end
  end
  idx.snapshots = kept
  save_index(dir, idx)
end

local function cleanup_by_count(dir, max_entries)
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
  prune_index_missing_files(dir)
end

local function cleanup_by_retention_days(dir, retention_days)
  if not retention_days or retention_days <= 0 then
    return
  end
  local cutoff = os.time() - retention_days * 24 * 3600
  local snaps = list_snapshots(dir)
  for _, p in ipairs(snaps) do
    local st = vim.loop.fs_stat(p)
    if st and st.mtime and st.mtime.sec and st.mtime.sec < cutoff then
      pcall(vim.loop.fs_unlink, p)
    end
  end
  prune_index_missing_files(dir)
end

function M.snapshot_current_file(file_abs, cfg, source)
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

  local content = read_file(file_abs)
  if content == nil then
    return
  end

  local snaps = list_snapshots(dir)
  local last = snaps[#snaps]
  if last then
    local prev = read_file(last)
    if prev == content then
      return
    end
  end

  local fname = Path.timestamp_name()
  local full = dir .. "/" .. fname
  write_file(full, content)

  append_index(dir, {
    file = fname,
    created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    epoch = os.time(),
    size = #content,
    sha256 = vim.fn.sha256(content),
    source = source or "manual",
  })

  cleanup_by_retention_days(dir, cfg.retention_days)
  cleanup_by_count(dir, cfg.max_entries_per_file)
end

function M.list_for_file(file_abs, cfg)
  file_abs = Path.normalize(file_abs)
  local root = Path.workspace_root(file_abs)
  local rel = Path.relpath(file_abs, root)
  local dir = Path.file_dir(cfg.root_dir, root, rel)
  return list_snapshots(dir), dir
end

function M.read_snapshot(path)
  return read_file(path)
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

function M.purge_for_file(file_abs, cfg)
  local snaps, dir = M.list_for_file(file_abs, cfg)
  for _, p in ipairs(snaps) do
    pcall(vim.loop.fs_unlink, p)
  end
  pcall(vim.loop.fs_unlink, Path.meta_file(dir))
  notify("Purged local history for current file", vim.log.levels.INFO, cfg)
end

M.notify = notify
return M
