# local-history.nvim

A minimal local history plugin for Neovim.

## Features

- Auto snapshot on `BufWritePost`
- Deduplicate by content
- `:LocalHistoryList`
- `:LocalHistoryDiff`
- `:LocalHistoryRestore`
- VSCode-style config key mapping support

## Install (lazy.nvim)

```lua
{
  "gaoqiangks/local-history.nvim",
  config = function()
    require("local_history").setup({
      ["local-history.enabled"] = true,
      ["local-history.trigger"] = "onSave",
      ["local-history.maxEntries"] = 200,
    })
  end,
}
