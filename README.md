# local-history.nvim

A Neovim plugin that ports the **local history workflow** (similar to VSCode local-history) to Neovim.

It automatically stores snapshots of file content over time, so you can:

- list history entries,
- diff old versions vs current buffer,
- restore any snapshot quickly,
- and apply retention/cleanup policies.

---

## Why this plugin

Sometimes you want quick “time machine” recovery for a single file without using Git commits for every tiny change.  
This plugin gives you:

- local snapshots on save/change/focus-lost,
- content-level deduplication (avoid duplicate snapshots),
- and fast restore.

---

## Features

- ✅ Auto snapshot triggers:
  - `BufWritePost` (save)
  - `TextChanged` / `TextChangedI` (change, with debounce)
  - `FocusLost`
- ✅ Skip duplicate snapshots (if content unchanged)
- ✅ Retention:
  - max entries per file
  - retention days
- ✅ Exclude rules:
  - pattern matching
  - max file size
  - skip binary files
- ✅ Commands:
  - `:LocalHistoryList`
  - `:LocalHistoryDiff`
  - `:LocalHistoryRestore`
  - `:LocalHistoryPurge`
- ✅ VSCode-style config key mapping (兼容字段名)

---

## Requirements

- Neovim >= 0.9 (recommended 0.10+)
- No external runtime required (pure Lua)

---

## Installation

### lazy.nvim

```lua
{
  "gaoqiangks/local-history.nvim",
  config = function()
    require("local_history").setup({
      enabled = true,
      save_on = { "BufWritePost" },
    })
  end,
}
```

### packer.nvim

```lua
use({
  "gaoqiangks/local-history.nvim",
  config = function()
    require("local_history").setup()
  end,
})
```

---

## Quick Start

1. Install plugin and run `setup`.
2. Open any file and save it multiple times.
3. Run:
   - `:LocalHistoryList`
   - `:LocalHistoryDiff`
   - `:LocalHistoryRestore`

If snapshots exist, list/diff/restore will work immediately.

---

## Commands

### `:LocalHistoryList`
List snapshots for current file.

### `:LocalHistoryDiff`
Select a snapshot, then open unified diff against current buffer.

### `:LocalHistoryRestore`
Select a snapshot and replace current buffer content with that snapshot.

### `:LocalHistoryPurge`
Delete all snapshots for current file.

---

## Configuration

## Default config

```lua
require("local_history").setup({
  enabled = true,

  -- Auto snapshot events
  save_on = { "BufWritePost" }, -- e.g. {"BufWritePost"}, {"TextChanged","TextChangedI"}, {"FocusLost"}

  -- Only used when save_on contains change events
  on_change_debounce_ms = 800,

  -- Minimum interval between two snapshots for the same file
  min_snapshot_interval_ms = 500,

  -- Storage root
  root_dir = vim.fn.stdpath("state") .. "/local-history",

  -- Retention policies
  max_entries_per_file = 200,
  retention_days = 30,

  -- Exclude rules (Lua patterns)
  exclude_patterns = {
    "%.git/",
    "node_modules/",
    "%.cache/",
    "%.swp$",
    "~$",
  },

  -- Skip files bigger than this
  max_file_size_kb = 1024,

  -- Binary files detection
  skip_binary = true,

  -- Show notifications
  notify = true,
})
```

---

## Trigger modes (VSCode-like behavior mapping)

### Save mode (recommended default)
```lua
require("local_history").setup({
  save_on = { "BufWritePost" },
})
```

### Change mode (high frequency, with debounce)
```lua
require("local_history").setup({
  save_on = { "TextChanged", "TextChangedI" },
  on_change_debounce_ms = 1000,
})
```

### Focus lost mode
```lua
require("local_history").setup({
  save_on = { "FocusLost" },
})
```

---

## VSCode config key compatibility

You can pass VSCode-style keys directly. Plugin maps them to Neovim internal fields.

### Example

```lua
require("local_history").setup({
  ["local-history.enabled"] = true,
  ["local-history.path"] = vim.fn.stdpath("state") .. "/local-history",
  ["local-history.maxEntries"] = 300,
  ["local-history.retentionDays"] = 14,
  ["local-history.exclude"] = { "%.git/", "node_modules/" },
  ["local-history.maxFileSizeKB"] = 2048,
  ["local-history.trigger"] = "onChange",
  ["local-history.debounceMs"] = 1000,
  ["local-history.minIntervalMs"] = 600,
})
```

### Mapping table

| VSCode-style key | Neovim internal key |
|---|---|
| `local-history.enabled` | `enabled` |
| `local-history.path` / `local-history.root` | `root_dir` |
| `local-history.maxEntries` / `local-history.maxFileEntries` | `max_entries_per_file` |
| `local-history.daysLimit` / `local-history.retentionDays` | `retention_days` |
| `local-history.exclude` / `local-history.excludePattern(s)` | `exclude_patterns` |
| `local-history.maxFileSizeKB` | `max_file_size_kb` |
| `local-history.maxFileSize` (bytes) | auto-converted to `max_file_size_kb` |
| `local-history.trigger = onSave` | `save_on = {"BufWritePost"}` |
| `local-history.trigger = onChange` | `save_on = {"TextChanged","TextChangedI"}` |
| `local-history.trigger = onFocusLost` | `save_on = {"FocusLost"}` |
| `local-history.debounceMs` | `on_change_debounce_ms` |
| `local-history.minIntervalMs` | `min_snapshot_interval_ms` |
| `local-history.notify` | `notify` |

> Priority rule: if both native key and VSCode-style key are provided, **native key wins**.

---

## Storage layout

Snapshots are stored under:

```text
<stdpath('state')>/local-history/<workspace_hash>/<relative_file_path>/<timestamp>.snap
```

Example:

```text
~/.local/state/nvim/local-history/ab12cd34ef56/src/main.ts/20260301-103045.snap
```

Each file history folder also stores an `index.json` metadata file.

---

## Retention behavior

Two cleanup rules are applied:

1. **`retention_days`**: remove old snapshots by age
2. **`max_entries_per_file`**: keep only latest N snapshots

Cleanup runs after each snapshot write.

---

## Known behavior notes

- `:LocalHistoryRestore` modifies current buffer content and marks it as modified (not auto-written).
- Diff currently uses unified diff text view.
- Exclude patterns use **Lua pattern syntax** (not full glob syntax).

---

## Recommended settings

For most users:

```lua
require("local_history").setup({
  save_on = { "BufWritePost" },
  max_entries_per_file = 300,
  retention_days = 30,
  skip_binary = true,
})
```

For aggressive tracking:

```lua
require("local_history").setup({
  save_on = { "TextChanged", "TextChangedI" },
  on_change_debounce_ms = 1200,
  min_snapshot_interval_ms = 800,
})
```

---

## Troubleshooting

### 1) No snapshots generated

Check:

- file is not excluded by `exclude_patterns`
- file is not too large (`max_file_size_kb`)
- file is not binary (`skip_binary = true`)
- trigger is correctly configured (`save_on`)

### 2) `:LocalHistoryList` says no snapshots

- Save the file at least once (`:w`) if using `BufWritePost`.
- Ensure current buffer has a real file path (`:echo expand('%:p')`).

### 3) Too many snapshots

- Increase `min_snapshot_interval_ms`
- Increase `on_change_debounce_ms`
- Prefer save trigger instead of change trigger

---

## Development

Repository layout:

```text
plugin/local_history.lua
lua/local_history/
  init.lua
  config.lua
  adapter.lua
  path.lua
  util.lua
  store.lua
  ui.lua
```

---

## Roadmap

- Telescope picker integration
- Side-by-side diff view
- Restore to new buffer / new file
- Workspace-wide purge
- More strict VSCode 1:1 config parity

---

## License

MIT

