if vim.g.loaded_local_history_plugin == 1 then
  return
end
vim.g.loaded_local_history_plugin = 1

require("local_history").setup()
