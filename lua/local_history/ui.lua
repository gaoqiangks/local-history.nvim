local Store = require("local_history.store")
local Util = require("local_history.util")

local M = {}

local function create_float_buffer(name, lines, filetype)
    local buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true
    vim.api.nvim_buf_set_name(buf, name)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = true
    if filetype then
        vim.bo[buf].filetype = filetype
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
    vim.bo[buf].modifiable = false
    return buf
end

local function open_float(lines, opts)
    opts = opts or {}
    local width = opts.width or math.floor(vim.o.columns * 0.8)
    local height = opts.height or math.floor(vim.o.lines * 0.75)
    local row = math.floor((vim.o.lines - height) / 2 - 1)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = create_float_buffer(opts.name or "LocalHistoryFloat", lines, opts.filetype)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = math.max(row, 0),
        col = math.max(col, 0),
        width = math.max(width, 40),
        height = math.max(height, 8),
        style = "minimal",
        border = opts.border or "rounded",
        title = opts.title,
        title_pos = "center",
    })

    -- 关闭快捷键
    vim.keymap.set("n", "q", function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end, { buffer = buf, silent = true })

    vim.keymap.set("n", "<Esc>", function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end, { buffer = buf, silent = true })

    return buf, win
end

function M.select_snapshot(file_abs, cfg, cb)
    local snaps = Store.list_for_file(file_abs, cfg)
    if #snaps == 0 then
        Store.notify("No local history snapshots for current file", vim.log.levels.INFO, cfg)
        return
    end

    local items, map = {}, {}
    for i = #snaps, 1, -1 do
        local p = snaps[i]
        local label = Util.basename(p)
        table.insert(items, label)
        map[label] = p
    end

    vim.ui.select(items, { prompt = "LocalHistory snapshots" }, function(choice)
        if choice then
            cb(map[choice])
        end
    end)
end

function M.list(file_abs, cfg)
    local snaps = Store.list_for_file(file_abs, cfg)
    if #snaps == 0 then
        Store.notify("No local history snapshots for current file", vim.log.levels.INFO, cfg)
        return
    end

    local lines = {}
    table.insert(lines, "Local History")
    table.insert(lines, string.rep("─", 80))
    table.insert(lines, "File: " .. file_abs)
    table.insert(lines, "Total snapshots: " .. tostring(#snaps))
    table.insert(lines, "")

    for i = #snaps, 1, -1 do
        local p = snaps[i]
        local name = Util.basename(p)
        local st = vim.loop.fs_stat(p)
        local size = st and st.size or 0
        local mtime = (st and st.mtime and st.mtime.sec) and os.date("%Y-%m-%d %H:%M:%S", st.mtime.sec) or "unknown"
        table.insert(lines, string.format("%4d. %s  |  %8d bytes  |  %s", #snaps - i + 1, name, size, mtime))
    end

    table.insert(lines, "")
    table.insert(lines, "q / <Esc> to close")
    table.insert(lines, ":LocalHistoryDiff to diff, :LocalHistoryRestore to restore")

    open_float(lines, {
        name = "LocalHistoryList",
        title = " LocalHistory List ",
        filetype = "markdown",
        width = math.floor(vim.o.columns * 0.85),
        height = math.floor(vim.o.lines * 0.75),
        border = "rounded",
    })
end

function M.diff_with_current(file_abs, cfg)
    M.select_snapshot(file_abs, cfg, function(snapshot_path)
        local old = Store.read_snapshot(snapshot_path)
        if not old then
            Store.notify("Failed to read snapshot", vim.log.levels.ERROR, cfg)
            return
        end

        local cur = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
        local diff = vim.diff(old, cur, { result_type = "unified" })
        if diff == "" then
            Store.notify("No difference", vim.log.levels.INFO, cfg)
            return
        end

        open_float(vim.split(diff, "\n", { plain = true }), {
            name = "LocalHistoryDiff",
            title = " LocalHistory Diff ",
            filetype = "diff",
            width = math.floor(vim.o.columns * 0.9),
            height = math.floor(vim.o.lines * 0.8),
            border = "rounded",
        })
    end)
end

function M.restore(file_abs, cfg)
    M.select_snapshot(file_abs, cfg, function(snapshot_path)
        local ok, err = Store.restore_to_current_buffer(snapshot_path)
        if not ok then
            Store.notify("Restore failed: " .. (err or ""), vim.log.levels.ERROR, cfg)
            return
        end
        Store.notify("Restored from " .. Util.basename(snapshot_path), vim.log.levels.INFO, cfg)
    end)
end

return M
