local M = {}

local function to_list(v)
  if v == nil then return nil end
  if type(v) == "table" then return v end
  if type(v) == "string" then return { v } end
  return nil
end

function M.from_vscode_like(opts)
  opts = opts or {}
  local out = vim.deepcopy(opts)

  if out.enabled == nil then
    out.enabled = opts["local-history.enabled"] or opts.localHistoryEnabled
  end

  if out.root_dir == nil then
    out.root_dir = opts["local-history.path"] or opts["local-history.root"] or opts.localHistoryPath
  end

  if out.max_entries_per_file == nil then
    out.max_entries_per_file = opts["local-history.maxEntries"] or opts["local-history.maxFileEntries"] or opts.localHistoryMaxEntries
  end

  if out.retention_days == nil then
    out.retention_days = opts["local-history.daysLimit"] or opts["local-history.retentionDays"] or opts.localHistoryRetentionDays
  end

  if out.exclude_patterns == nil then
    out.exclude_patterns = to_list(
      opts["local-history.exclude"] or opts["local-history.excludePattern"] or opts["local-history.excludePatterns"] or opts.localHistoryExclude
    )
  end

  if out.max_file_size_kb == nil then
    local kb = opts["local-history.maxFileSizeKB"] or opts["local-history.maxFileSizeKb"] or opts.localHistoryMaxFileSizeKB
    local bytes = opts["local-history.maxFileSize"] or opts.localHistoryMaxFileSize
    if kb ~= nil then
      out.max_file_size_kb = kb
    elseif bytes ~= nil then
      out.max_file_size_kb = math.floor((tonumber(bytes) or 0) / 1024)
    end
  end

  if out.save_on == nil then
    local trigger = opts["local-history.trigger"] or opts.localHistoryTrigger
    local save_on = opts["local-history.saveOn"] or opts.localHistorySaveOn
    if save_on ~= nil then
      out.save_on = to_list(save_on)
    elseif trigger == "onSave" then
      out.save_on = { "BufWritePost" }
    elseif trigger == "onChange" then
      out.save_on = { "TextChanged", "TextChangedI" }
    end
  end

  if out.notify == nil then
    out.notify = opts["local-history.notify"]
  end

  return out
end

return M
