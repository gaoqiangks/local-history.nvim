# local-history.nvim

Neovim port of local history workflow (VSCode-like), with snapshot, diff, restore, cleanup and VSCode-style config key mapping.

## Features

- Auto snapshot on:
  - `BufWritePost` (onSave)
  - `TextChanged` / `TextChangedI` (onChange + debounce)
  - `FocusLost` (onFocusLost)
- Deduplicate by content
- Retention policies:
  - `max_entries_per_file`
  - `retention_days`
- Skip rules:
  - exclude patterns
  - max file size
  - binary file skip
- Commands:
  - `:LocalHistoryList`
  - `:LocalHistoryDiff`
  - `:LocalHistoryRestore`
  - `:LocalHistoryPurge`
- VSCode-style config mapping

## Install (lazy.nvim)

```lua
{
  "gaoqiangks/local-history.nvim",
  config = function()
    require("local_history").setup({
      ["local-history.enabled"] = true,
      ["local-history.trigger"] = "onSave",
      ["local-history.maxEntries"] = 200,
      ["local-history.retentionDays"] = 30,
    })
  end,
}
