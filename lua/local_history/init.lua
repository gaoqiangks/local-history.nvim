local Config = require("local_history.config")
local Store = require("local_history.store")
local UI = require("local_history.ui")
local Adapter = require("local_history.adapter")

local M = {
  _cfg = nil,
  _augroup = nil,
}

local function current_file_abs()
  return vim.api.nvim_buf_get_name(0)
end

local function define_commands()
  vim.api.nvim_create_user_command("LocalHistoryList", function()
    UI.list(current_file_abs(), M._cfg)
  end, {})

  vim.api.nvim_create_user_command("LocalHistoryDiff", function()
    UI.diff_with_current(current_file_abs(), M._cfg)
  end, {})

  vim.api.nvim_create_user_command("LocalHistoryRestore", function()
    UI.restore(current_file_abs(), M._cfg)
  end, {})
end

local function define_autocmds()
  if M._augroup then
    pcall(vim.api.nvim_del_augroup_by_id, M._augroup)
  end
  M._augroup = vim.api.nvim_create_augroup("LocalHistoryAutoSave", { clear = true })

  for _, evt in ipairs(M._cfg.save_on or {}) do
    vim.api.nvim_create_autocmd(evt, {
      group = M._augroup,
      callback = function(args)
        local file = vim.api.nvim_buf_get_name(args.buf)
        Store.snapshot_current_file(file, M._cfg)
      end,
    })
  end
end

function M.setup(opts)
  local adapted = Adapter.from_vscode_like(opts or {})
  M._cfg = Config.merge(adapted)
  define_commands()
  define_autocmds()
end

return M
