local M = {}

M.defaults = {
  enabled = true,
  save_on = { "BufWritePost" }, -- BufWritePost | TextChanged | TextChangedI | FocusLost
  on_change_debounce_ms = 800,
  min_snapshot_interval_ms = 500,

  root_dir = ".history", -- This can be an absolute path or relative to each file's directory
  max_entries_per_file = 200,
  retention_days = 30,

  exclude_patterns = {
    "%.git/",
    "node_modules/",
    "%.cache/",
    "%.swp$",
    "~$",
  },

  max_file_size_kb = 1024,
  skip_binary = true,
  notify = true,
}

function M.merge(user_opts)
  return vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
