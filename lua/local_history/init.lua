local Config = require("local_history.config")
local Store = require("local_history.store")
local UI = require("local_history.ui")
local Adapter = require("local_history.adapter")
local Util = require("local_history.util")

local M = {
  _cfg = nil,
  _augroup = nil,
  _timers = {},
  _last_snapshot_ms = {},
}

local function file_of_buf(buf)
  return vim.api.nvim_buf_get_name(buf or 0)
end

local function can_snapshot_now(file)
  local now = Util.now_ms()
  local last = M._last_snapshot_ms[file] or 0
  if now - last < (M._cfg.min_snapshot_interval_ms or 0) then
    return false
  end
  M._last_snapshot_ms[file] = now
  return true
end

local function snapshot(file, source)
  if file == "" then return end
  if not can_snapshot_now(file) then return end
  Store.snapshot_current_file(file, M._cfg, source)
end

local function debounce_snapshot(file, source)
  local key = file
  local old = M._timers[key]
  if old then
    old:stop()
    old:close()
    M._timers[key] = nil
  end
  local t = vim.loop.new_timer()
  M._timers[key] = t
  t:start(M._cfg.on_change_debounce_ms or 800, 0, vim.schedule_wrap(function()
    if M._timers[key] then
      M._timers[key]:stop()
      M._timers[key]:close()
      M._timers[key] = nil
    end
    snapshot(file, source)
  end))
end

local function define_commands()
  vim.api.nvim_create_user_command("LocalHistoryList", function()
    UI.list(file_of_buf(0), M._cfg)
  end, {})

  vim.api.nvim_create_user_command("LocalHistoryDiff", function()
    UI.diff_with_current(file_of_buf(0), M._cfg)
  end, {})

  vim.api.nvim_create_user_command("LocalHistoryRestore", function()
    UI.restore(file_of_buf(0), M._cfg)
  end, {})

  vim.api.nvim_create_user_command("LocalHistoryPurge", function()
    Store.purge_for_file(file_of_buf(0), M._cfg)
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
        local file = file_of_buf(args.buf)
        if evt == "TextChanged" or evt == "TextChangedI" then
          debounce_snapshot(file, evt)
        else
          snapshot(file, evt)
        end
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
