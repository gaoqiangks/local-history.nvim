local Path = require("local_history.path")
local Util = require("local_history.util")

local M = {}
M._last_cleanup_at = M._last_cleanup_at or {}

local function now_ms()
    return vim.loop.hrtime() / 1e6
end

local function is_profile_enabled(cfg)
    return cfg and cfg.profile == true
end

local function profile_log(cfg, phase, start_ms, extra)
    if not is_profile_enabled(cfg) then
        return
    end
    local cost = now_ms() - start_ms
    local msg = string.format("[profile] %s: %.2f ms%s", phase, cost, extra and (" | " .. extra) or "")
    vim.schedule(function()
        vim.notify(msg, vim.log.levels.INFO, { title = "local-history" })
    end)
end

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
    if max_entries == nil or max_entries < 0 then
        return
    end
    if max_entries == 0 then
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
    if retention_days == nil or retention_days < 0 then
        return
    end
    if retention_days == 0 then
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

local function cleanup_disabled(cfg)
    if cfg.cleanup_enabled == false then
        return true
    end
    local max_entries = cfg.max_entries_per_file
    local retention_days = cfg.retention_days
    if (max_entries ~= nil and max_entries < 0) and (retention_days ~= nil and retention_days < 0) then
        return true
    end
    return false
end

local function should_run_cleanup(dir, cfg)
    if cleanup_disabled(cfg) then
        return false
    end
    local interval = (cfg.cleanup_interval_sec or 60)
    if interval <= 0 then
        return true
    end
    local now = os.time()
    local last = M._last_cleanup_at[dir] or 0
    if now - last < interval then
        return false
    end
    M._last_cleanup_at[dir] = now
    return true
end

local function dedupe_enabled(cfg)
    return cfg.dedupe_enabled ~= false
end

local function snapshot_impl(file_abs, cfg, source)
    local t_all = now_ms()

    if not cfg.enabled or file_abs == "" then
        return
    end
    file_abs = Path.normalize(file_abs)

    local t_ex = now_ms()
    if should_exclude(file_abs, cfg) then
        profile_log(cfg, "skip_excluded", t_ex, file_abs)
        return
    end
    profile_log(cfg, "check_exclude", t_ex)

    local t_path = now_ms()
    local root = Path.workspace_root(file_abs)
    local rel = Path.relpath(file_abs, root)
    local dir = Path.file_dir(cfg.root_dir, root, rel)
    Path.ensure_dir(dir)
    profile_log(cfg, "prepare_path", t_path, dir)

    local t_read = now_ms()
    local content = read_file(file_abs)
    profile_log(cfg, "read_current_file", t_read, content and ("size=" .. #content) or "nil")
    if content == nil then
        return
    end

    if dedupe_enabled(cfg) then
        local t_last = now_ms()
        local snaps = list_snapshots(dir)
        local last = snaps[#snaps]
        profile_log(cfg, "list_snapshots", t_last, "count=" .. #snaps)

        if last then
            local t_prev = now_ms()
            local prev = read_file(last)
            profile_log(cfg, "read_last_snapshot", t_prev, Util.basename(last))
            if prev == content then
                profile_log(cfg, "skip_duplicate", t_all)
                return
            end
        end
    else
        profile_log(cfg, "dedupe_skipped", now_ms())
    end

    local fname = Path.timestamp_name()
    local full = dir .. "/" .. fname

    local t_write = now_ms()
    write_file(full, content)
    profile_log(cfg, "write_snapshot_file", t_write, fname)

    local t_sha = now_ms()
    local sha = vim.fn.sha256(content)
    profile_log(cfg, "sha256", t_sha)

    local t_index = now_ms()
    append_index(dir, {
        file = fname,
        created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        epoch = os.time(),
        size = #content,
        sha256 = sha,
        source = source or "manual",
    })
    profile_log(cfg, "append_index", t_index)

    notify(string.format("Snapshot saved: %s (%s)", fname, Util.basename(file_abs)), vim.log.levels.INFO, cfg)

    if should_run_cleanup(dir, cfg) then
        local t_ret = now_ms()
        cleanup_by_retention_days(dir, cfg.retention_days)
        profile_log(cfg, "cleanup_retention_days", t_ret)

        local t_cnt = now_ms()
        cleanup_by_count(dir, cfg.max_entries_per_file)
        profile_log(cfg, "cleanup_max_entries", t_cnt)
    else
        profile_log(cfg, "cleanup_skipped", now_ms(), "disabled_or_interval")
    end

    profile_log(cfg, "snapshot_total", t_all, Util.basename(file_abs))
end

function M.snapshot_current_file(file_abs, cfg, source)
    vim.schedule(function()
        local ok, err = pcall(snapshot_impl, file_abs, cfg, source)
        if not ok then
            notify("Snapshot failed: " .. tostring(err), vim.log.levels.ERROR, cfg)
        end
    end)
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
