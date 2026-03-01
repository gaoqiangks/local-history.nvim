local Store = require("local_history.store")
local Util = require("local_history.util")

local M = {}

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
  local lines = { "Local History:" }
  for i = #snaps, 1, -1 do
    table.insert(lines, "  " .. Util.basename(snaps[i]))
  end
  Store.notify(table.concat(lines, "\n"), vim.log.levels.INFO, cfg)
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
    vim.cmd("new")
    local b = vim.api.nvim_get_current_buf()
    vim.bo[b].buftype = "nofile"
    vim.bo[b].bufhidden = "wipe"
    vim.bo[b].swapfile = false
    vim.bo[b].filetype = "diff"
    vim.api.nvim_buf_set_name(b, "LocalHistoryDiff")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, vim.split(diff, "\n", { plain = true }))
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
