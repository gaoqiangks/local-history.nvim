local M = {}

M.defaults = {
  enabled = true,
  save_on = { "BufWritePost" },
  root_dir = vim.fn.stdpath("state") .. "/local-history",
  max_entries_per_file = 200,
  exclude_patterns = {
    "%.git/",
    "node_modules/",
    "%.cache/",
  },
  max_file_size_kb = 1024,
  notify = true,
}

function M.merge(user_opts)
  return vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
