# local-history.nvim

Neovim port of local history workflow (VSCode-like), with snapshot, diff, restore, cleanup, VSCode-style config key mapping, and **save notification**.

## Features

- Auto snapshot on:
  - `BufWritePost` (onSave)
  - `TextChanged` / `TextChangedI` (onChange + debounce)
  - `FocusLost` (onFocusLost)
- Deduplicate by content
- Retention:
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
- **Notify on successful snapshot save** (when `notify = true`)

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
      notify = true,
    })
  end,
}
